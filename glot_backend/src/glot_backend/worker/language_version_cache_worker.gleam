import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/error/db_error
import glot_backend/effect/error/run_request_error
import glot_backend/erlang
import glot_backend/server_mode
import glot_backend/worker/app_config_cache_worker
import glot_core/language as language_module
import glot_core/run
import wisp

const call_timeout_ms = 5000

pub type Message {
  GetLanguageVersion(
    language: language_module.Language,
    reply: process.Subject(
      Result(run.RunResult, run_request_error.RunRequestError),
    ),
  )
  RefreshConfig
  Tick
  RefreshNext
  FetchCompleted(
    language: language_module.Language,
    fetched_at_ns: Int,
    result: Result(run.RunResult, run_request_error.RunRequestError),
  )
}

type InFlight {
  InFlight(
    waiters: List(
      process.Subject(Result(run.RunResult, run_request_error.RunRequestError)),
    ),
    refresh: Bool,
  )
}

pub type FetchHandlers {
  FetchHandlers(
    fetch_language_version: fn(
      process.Subject(app_config_cache_worker.Message),
      language_module.Language,
      Int,
    ) -> Result(run.RunResult, run_request_error.RunRequestError),
    get_config: fn(process.Subject(app_config_cache_worker.Message)) ->
      Result(dynamic_config.DynamicConfig, db_error.DbQueryError),
    now_ns: fn() -> Int,
    supported_languages: fn() -> List(language_module.Language),
  )
}

type CacheEntry {
  CacheEntry(run_result: run.RunResult, refreshed_at_ns: Int)
}

type State {
  State(
    subject: process.Subject(Message),
    app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
    server_mode_subject: process.Subject(server_mode.Message),
    fetch_handlers: FetchHandlers,
    config: dynamic_config.LanguageVersionCacheWorkerConfig,
    cached_versions: dict.Dict(language_module.Language, CacheEntry),
    in_flight: dict.Dict(language_module.Language, InFlight),
    refresh_queue: List(language_module.Language),
    refresh_language: option.Option(language_module.Language),
  )
}

pub fn start(
  name: process.Name(Message),
  config: context.Config,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
) {
  start_with_handlers(
    name,
    config,
    app_config_cache_subject,
    server_mode_subject,
    default_fetch_handlers(),
  )
}

pub fn start_with_handlers(
  name: process.Name(Message),
  _config: context.Config,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
  fetch_handlers: FetchHandlers,
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject: subject,
        app_config_cache_subject: app_config_cache_subject,
        server_mode_subject: server_mode_subject,
        fetch_handlers: fetch_handlers,
        config: dynamic_config.language_version_cache_worker_config(
          dynamic_config.empty(),
        ),
        cached_versions: dict.new(),
        in_flight: dict.new(),
        refresh_queue: [],
        refresh_language: option.None,
      )
    let _ = process.send(subject, RefreshConfig)
    let _ = process.send(subject, Tick)
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(
  name: process.Name(Message),
  config: context.Config,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
) {
  supervision.worker(fn() {
    start(name, config, app_config_cache_subject, server_mode_subject)
  })
}

pub fn get_language_version(
  subject: process.Subject(Message),
  language: language_module.Language,
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  process.call(subject, call_timeout_ms, fn(reply) {
    GetLanguageVersion(language:, reply:)
  })
}

fn default_fetch_handlers() -> FetchHandlers {
  FetchHandlers(
    fetch_language_version: fetch_language_version,
    get_config: app_config_cache_worker.get_config,
    now_ns: erlang.perf_counter_ns,
    supported_languages: language_module.list,
  )
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    GetLanguageVersion(language, reply) -> {
      let now_ns = state.fetch_handlers.now_ns()
      let #(next_state, maybe_result) =
        lookup_language_version(state, language, now_ns, reply)

      case maybe_result {
        Ok(run_result) -> {
          process.send(reply, Ok(run_result))
          actor.continue(next_state)
        }
        Error(Nil) -> actor.continue(next_state)
      }
    }
    RefreshConfig -> actor.continue(refresh_config(state))
    Tick -> {
      let state = refresh_config(state)
      let _ =
        process.send_after(
          state.subject,
          state.config.refresh_interval_ms,
          Tick,
        )
      case should_schedule_refreshes(state) {
        True ->
          actor.continue(
            state
            |> enqueue_due_refreshes()
            |> schedule_refresh_if_idle(-state.config.refresh_step_delay_ms),
          )
        False -> actor.continue(state)
      }
    }
    RefreshNext ->
      case should_schedule_refreshes(state) {
        True -> actor.continue(start_next_refresh(state))
        False -> actor.continue(state)
      }
    FetchCompleted(language, fetched_at_ns, result) ->
      actor.continue(complete_fetch(state, language, fetched_at_ns, result))
  }
}

fn lookup_language_version(
  state: State,
  language: language_module.Language,
  now_ns: Int,
  reply: process.Subject(
    Result(run.RunResult, run_request_error.RunRequestError),
  ),
) -> #(State, Result(run.RunResult, Nil)) {
  case dict.get(state.cached_versions, language) {
    Ok(entry) -> {
      let next_state = case is_stale(state, entry, now_ns) {
        True -> maybe_start_stale_refresh(state, language)
        False -> state
      }
      #(next_state, Ok(entry.run_result))
    }
    Error(_) ->
      case dict.has_key(state.in_flight, language) {
        True -> #(enqueue_waiter(state, language, reply), Error(Nil))
        False -> #(
          state
            |> ensure_fetch_started(language, False)
            |> enqueue_waiter(language, reply),
          Error(Nil),
        )
      }
  }
}

fn maybe_start_stale_refresh(
  state: State,
  language: language_module.Language,
) -> State {
  case should_schedule_refreshes(state) {
    True -> ensure_fetch_started(state, language, True)
    False -> state
  }
}

fn enqueue_due_refreshes(state: State) -> State {
  let now_ns = state.fetch_handlers.now_ns()
  let supported_languages = state.fetch_handlers.supported_languages()

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
  case
    is_refresh_pending(state, language) || is_refresh_in_flight(state, language)
  {
    True -> state
    False ->
      State(
        ..state,
        refresh_queue: list.append(state.refresh_queue, [language]),
      )
  }
}

fn enqueue_waiter(
  state: State,
  language: language_module.Language,
  reply: process.Subject(
    Result(run.RunResult, run_request_error.RunRequestError),
  ),
) -> State {
  let in_flight = case dict.get(state.in_flight, language) {
    Ok(in_flight) ->
      InFlight(
        waiters: [reply, ..in_flight.waiters],
        refresh: in_flight.refresh,
      )
    Error(_) -> InFlight(waiters: [reply], refresh: False)
  }

  State(..state, in_flight: dict.insert(state.in_flight, language, in_flight))
}

fn ensure_fetch_started(
  state: State,
  language: language_module.Language,
  refresh: Bool,
) -> State {
  case dict.has_key(state.in_flight, language) {
    True -> state
    False -> {
      let subject = state.subject
      let app_config_cache_subject = state.app_config_cache_subject
      let fetch_handlers = state.fetch_handlers

      let _ =
        process.spawn_unlinked(fn() {
          let result =
            fetch_handlers.fetch_language_version(
              app_config_cache_subject,
              language,
              state.config.default_timeout_ms,
            )
          let fetched_at_ns = fetch_handlers.now_ns()
          process.send(
            subject,
            FetchCompleted(language, fetched_at_ns:, result: result),
          )
        })

      State(
        ..state,
        in_flight: dict.insert(
          state.in_flight,
          language,
          InFlight(waiters: [], refresh: refresh),
        ),
      )
    }
  }
}

fn fetch_language_version(
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language: language_module.Language,
  timeout_ms: Int,
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  app_config_cache_worker.get_config(app_config_cache_subject)
  |> result.map_error(map_query_error)
  |> result.try(fn(config) {
    case dynamic_config.docker_run_config(config) {
      option.Some(docker_run) ->
        docker_run_handlers.run_code(
          docker_run,
          run_request(language),
          timeout_ms,
        )
      option.None -> {
        wisp.log_warning("Missing docker_run app_config")
        Error(run_request_error.ServerRunRequestError)
      }
    }
  })
}

fn run_request(language: language_module.Language) -> run.RunRequest {
  run.RunRequest(
    image: language_module.container_image(language),
    payload: run.RunRequestPayload(
      run_instructions: language_module.version_run_instructions(language),
      files: [],
      stdin: option.None,
    ),
  )
}

fn map_query_error(
  err: db_error.DbQueryError,
) -> run_request_error.RunRequestError {
  let db_error.DbQueryError(message: message) = err
  wisp.log_warning("Failed to load language version config: " <> message)
  run_request_error.ServerRunRequestError
}

fn refresh_config(state: State) -> State {
  case state.fetch_handlers.get_config(state.app_config_cache_subject) {
    Ok(config) ->
      State(
        ..state,
        config: dynamic_config.language_version_cache_worker_config(config),
      )
    Error(err) -> {
      let db_error.DbQueryError(message: message) = err
      wisp.log_warning(
        "Failed to refresh language version cache worker config: " <> message,
      )
      state
    }
  }
}

fn schedule_refresh_if_idle(state: State, base_delay_ms: Int) -> State {
  case state.refresh_language, state.refresh_queue {
    option.None, [_first, ..] -> {
      let jitter_ms = int.random(state.config.refresh_step_jitter_ms + 1)
      let _ =
        process.send_after(
          state.subject,
          base_delay_ms + state.config.refresh_step_delay_ms + jitter_ms,
          RefreshNext,
        )
      state
    }
    _, _ -> state
  }
}

fn start_next_refresh(state: State) -> State {
  case state.refresh_language, state.refresh_queue {
    option.Some(_), _ -> state
    option.None, [] -> state
    option.None, [language, ..rest] ->
      State(
        ..state,
        refresh_queue: rest,
        refresh_language: option.Some(language),
      )
      |> ensure_fetch_started(language, True)
  }
}

fn complete_fetch(
  state: State,
  language: language_module.Language,
  fetched_at_ns: Int,
  result: Result(run.RunResult, run_request_error.RunRequestError),
) -> State {
  let in_flight = case dict.get(state.in_flight, language) {
    Ok(in_flight) -> in_flight
    Error(_) -> InFlight(waiters: [], refresh: False)
  }

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

  case result {
    Ok(run_result) -> {
      let next_state =
        State(
          ..next_state,
          cached_versions: dict.insert(
            next_state.cached_versions,
            language,
            CacheEntry(run_result:, refreshed_at_ns: fetched_at_ns),
          ),
        )
      reply_waiters(in_flight.waiters, Ok(run_result))
      next_state
      |> schedule_refresh_if_idle(0)
    }
    Error(err) -> {
      wisp.log_warning(
        "Failed to refresh language version cache for "
        <> language_module.to_string(language)
        <> ": "
        <> string_from_run_request_error(err),
      )
      reply_waiters(in_flight.waiters, Error(err))
      next_state
      |> schedule_refresh_if_idle(0)
    }
  }
}

fn is_refresh_pending(
  state: State,
  language: language_module.Language,
) -> Bool {
  list.any(state.refresh_queue, fn(queued_language) {
    queued_language == language
  })
}

fn is_refresh_in_flight(
  state: State,
  language: language_module.Language,
) -> Bool {
  case state.refresh_language {
    option.Some(refresh_language) -> refresh_language == language
    option.None -> False
  }
}

fn should_schedule_refreshes(state: State) -> Bool {
  case server_mode.get_mode(state.server_mode_subject) {
    server_mode.ShuttingDown -> False
    _ -> True
  }
}

fn reply_waiters(
  waiters: List(
    process.Subject(Result(run.RunResult, run_request_error.RunRequestError)),
  ),
  result: Result(run.RunResult, run_request_error.RunRequestError),
) -> Nil {
  list.each(waiters, fn(reply) { process.send(reply, result) })
}

fn is_stale(state: State, entry: CacheEntry, now_ns: Int) -> Bool {
  now_ns - entry.refreshed_at_ns >= ms_to_ns(state.config.refresh_interval_ms)
}

fn ms_to_ns(value_ms: Int) -> Int {
  value_ms * 1_000_000
}

fn string_from_run_request_error(
  err: run_request_error.RunRequestError,
) -> String {
  case err {
    run_request_error.ClientRunRequestError(message) -> message
    run_request_error.ServerRunRequestError -> "server run request error"
  }
}
