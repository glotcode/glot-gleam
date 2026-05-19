import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option
import glot_backend/dynamic_config
import glot_backend/effect/error/run_request_error
import glot_backend/worker/cache_worker_support
import glot_core/language as language_module
import glot_core/run

pub const bootstrap_poll_interval_ms = 100

pub type Reply =
  Result(run.RunResult, run_request_error.RunRequestError)

pub type State {
  State(
    config: dynamic_config.LanguageVersionCacheWorkerConfig,
    docker_run_configured: Bool,
    cached_versions: dict.Dict(
      language_module.Language,
      cache_worker_support.CacheEntry(run.RunResult),
    ),
    in_flight: dict.Dict(
      language_module.Language,
      cache_worker_support.InFlight(Reply, Bool),
    ),
    refresh_queue: List(language_module.Language),
    refresh_language: option.Option(language_module.Language),
  )
}

pub type Command {
  Reply(reply_to: process.Subject(Reply), result: Reply)
  StartFetch(language: language_module.Language, timeout_ms: Int)
  ScheduleTick(delay_ms: Int)
  ScheduleRefreshNext(
    base_delay_ms: Int,
    step_delay_ms: Int,
    max_jitter_ms: Int,
  )
  LogRefreshError(language: language_module.Language, err: run_request_error.RunRequestError)
}

pub fn new() -> State {
  State(
    config: dynamic_config.language_version_cache_worker_config(
      dynamic_config.empty(),
    ),
    docker_run_configured: False,
    cached_versions: dict.new(),
    in_flight: dict.new(),
    refresh_queue: [],
    refresh_language: option.None,
  )
}

pub fn set_config(
  state: State,
  config: dynamic_config.DynamicConfig,
) -> State {
  State(
    ..state,
    config: dynamic_config.language_version_cache_worker_config(config),
    docker_run_configured: dynamic_config.docker_run_config(config)
      != option.None,
  )
}

pub fn docker_run_configured(state: State) -> Bool {
  state.docker_run_configured
}

pub fn on_get_language_version(
  state: State,
  language: language_module.Language,
  reply: process.Subject(Reply),
  now_ns: Int,
  can_fetch: Bool,
  can_update: Bool,
) -> #(State, List(Command)) {
  case
    cache_worker_support.keyed_lookup(
      state.cached_versions,
      state.in_flight,
      language,
      reply,
      now_ns,
      state.config.refresh_interval_ms,
      can_fetch,
      Ok,
      Error(run_request_error.ServerRunRequestError),
      False,
    )
  {
    cache_worker_support.ReplyNow(result, start_refresh) -> {
      let #(next_state, refresh_commands) =
        case start_refresh && can_update && !dict.has_key(state.in_flight, language) {
          True -> start_fetch(state, language, True)
          False -> #(state, [])
        }
      #(next_state, [Reply(reply, result), ..refresh_commands])
    }
    cache_worker_support.AwaitFetch(in_flight, start_fetch_now) -> {
      let state =
        State(..state, in_flight: dict.insert(state.in_flight, language, in_flight))
      case start_fetch_now {
        True -> start_fetch(state, language, False)
        False -> #(state, [])
      }
    }
  }
}

pub fn on_tick(
  state: State,
  supported_languages: List(language_module.Language),
  now_ns: Int,
  can_update: Bool,
) -> #(State, List(Command)) {
  let tick_delay_ms =
    case can_update {
      True -> state.config.refresh_interval_ms
      False -> bootstrap_poll_interval_ms
    }
  let commands = [ScheduleTick(tick_delay_ms)]

  case can_update {
    False -> #(state, commands)
    True -> {
      let state = enqueue_due_refreshes(state, supported_languages, now_ns)
      let #(next_state, refresh_commands) =
        case should_start_initial_refresh_immediately(state) {
          True -> start_next_refresh(state)
          False -> schedule_refresh_if_idle(state, -state.config.refresh_step_delay_ms)
        }
      #(next_state, list.append(commands, refresh_commands))
    }
  }
}

pub fn on_refresh_next(
  state: State,
  can_update: Bool,
) -> #(State, List(Command)) {
  case can_update {
    True -> start_next_refresh(state)
    False -> #(state, [])
  }
}

pub fn on_fetch_completed(
  state: State,
  language: language_module.Language,
  fetched_at_ns: Int,
  result: Reply,
) -> #(State, List(Command)) {
  let in_flight =
    cache_worker_support.keyed_in_flight(state.in_flight, language, False)

  let next_state = {
    let refresh_language = case state.refresh_language {
      option.Some(current) if current == language -> option.None
      _ -> state.refresh_language
    }

    State(
      ..state,
      in_flight: dict.delete(state.in_flight, language),
      refresh_language: refresh_language,
    )
  }

  let reply_commands =
    list.map(in_flight.waiters, fn(reply) { Reply(reply, result) })

  case result {
    Ok(_run_result) -> {
      let assert option.Some(cache_entry) =
        cache_worker_support.cache_result(fetched_at_ns, result)
      let next_state =
        State(
          ..next_state,
          cached_versions: dict.insert(
            next_state.cached_versions,
            language,
            cache_entry,
          ),
        )
      let #(next_state, refresh_commands) = schedule_refresh_if_idle(next_state, 0)
      #(next_state, list.append(reply_commands, refresh_commands))
    }
    Error(err) -> {
      let #(next_state, refresh_commands) = schedule_refresh_if_idle(next_state, 0)
      #(
        next_state,
        [LogRefreshError(language, err), ..list.append(reply_commands, refresh_commands)],
      )
    }
  }
}

fn enqueue_due_refreshes(
  state: State,
  supported_languages: List(language_module.Language),
  now_ns: Int,
) -> State {
  list.fold(supported_languages, state, fn(state, language) {
    case dict.get(state.cached_versions, language) {
      Ok(entry) ->
        case is_stale(state, entry, now_ns) {
          True -> enqueue_refresh(state, language)
          False -> state
        }
      Error(_) -> enqueue_refresh(state, language)
    }
  })
}

fn enqueue_refresh(state: State, language: language_module.Language) -> State {
  case is_refresh_pending(state, language) || is_refresh_in_flight(state, language) {
    True -> state
    False ->
      State(
        ..state,
        refresh_queue: list.append(state.refresh_queue, [language]),
      )
  }
}

fn start_fetch(
  state: State,
  language: language_module.Language,
  refresh: Bool,
) -> #(State, List(Command)) {
  let existing_in_flight =
    cache_worker_support.keyed_in_flight(state.in_flight, language, False)
  let next_in_flight =
    cache_worker_support.InFlight(
      waiters: existing_in_flight.waiters,
      meta: existing_in_flight.meta || refresh,
    )
  let next_state =
    State(
      ..state,
      in_flight: dict.insert(
        state.in_flight,
        language,
        next_in_flight,
      ),
    )
  #(
    next_state,
    [StartFetch(language, state.config.default_timeout_ms)],
  )
}

fn schedule_refresh_if_idle(
  state: State,
  base_delay_ms: Int,
) -> #(State, List(Command)) {
  case state.refresh_language, state.refresh_queue {
    option.None, [_first, ..] -> #(
      state,
      [
        ScheduleRefreshNext(
          base_delay_ms: base_delay_ms,
          step_delay_ms: state.config.refresh_step_delay_ms,
          max_jitter_ms: state.config.refresh_step_jitter_ms,
        ),
      ],
    )
    _, _ -> #(state, [])
  }
}

fn start_next_refresh(state: State) -> #(State, List(Command)) {
  case state.refresh_language, state.refresh_queue {
    option.Some(_), _ -> #(state, [])
    option.None, [] -> #(state, [])
    option.None, [language, ..rest] -> {
      let state =
        State(
          ..state,
          refresh_queue: rest,
          refresh_language: option.Some(language),
        )
      case dict.has_key(state.in_flight, language) {
        True -> #(state, [])
        False -> start_fetch(state, language, True)
      }
    }
  }
}

fn is_refresh_pending(state: State, language: language_module.Language) -> Bool {
  list.any(state.refresh_queue, fn(queued_language) {
    queued_language == language
  })
}

fn is_refresh_in_flight(state: State, language: language_module.Language) -> Bool {
  case state.refresh_language {
    option.Some(refresh_language) -> refresh_language == language
    option.None -> False
  }
}

fn should_start_initial_refresh_immediately(state: State) -> Bool {
  dict.is_empty(state.cached_versions)
  && dict.is_empty(state.in_flight)
  && state.refresh_queue != []
  && state.refresh_language == option.None
}

fn is_stale(
  state: State,
  entry: cache_worker_support.CacheEntry(run.RunResult),
  now_ns: Int,
) -> Bool {
  cache_worker_support.is_stale(entry, now_ns, state.config.refresh_interval_ms)
}
