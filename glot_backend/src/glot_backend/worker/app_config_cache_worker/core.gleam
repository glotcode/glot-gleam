import gleam/erlang/process
import gleam/list
import glot_backend/dynamic_config
import glot_backend/effect/error/db_error
import glot_backend/worker/cache_worker_state
import glot_backend/worker/cache_worker_support

pub const refresh_interval_ms = 60_000

pub type Reply =
  Result(dynamic_config.DynamicConfig, db_error.DbQueryError)

pub type State {
  State(
    cache: cache_worker_state.Single(dynamic_config.DynamicConfig, Reply, Nil),
  )
}

pub type Command {
  ScheduleTick(delay_ms: Int)
  StartFetch
  Reply(reply_to: process.Subject(Reply), result: Reply)
  LogRefreshError(err: db_error.DbQueryError)
}

pub fn new() -> State {
  State(cache: cache_worker_state.new_single())
}

pub fn on_get(
  state: State,
  reply: process.Subject(Reply),
  now_ns: Int,
  can_fetch: Bool,
) -> #(State, List(Command)) {
  let #(cache, decision) =
    cache_worker_state.single_lookup(
      state.cache,
      reply,
      now_ns,
      refresh_interval_ms,
      can_fetch,
      Ok,
      Ok(dynamic_config.empty()),
      Nil,
    )

  case decision {
    cache_worker_support.ReplyNow(result, start_refresh) -> {
      let #(next_state, refresh_commands) = case start_refresh && can_fetch {
        True -> start_fetch_if_idle(state)
        False -> #(state, [])
      }

      #(next_state, [Reply(reply, result), ..refresh_commands])
    }
    cache_worker_support.AwaitFetch(_, start_fetch) -> {
      let next_state = State(cache: cache)
      let commands = case start_fetch {
        True -> [StartFetch]
        False -> []
      }
      #(next_state, commands)
    }
  }
}

pub fn on_refresh_requested(
  state: State,
  reply: process.Subject(Reply),
  can_fetch: Bool,
) -> #(State, List(Command)) {
  let #(cache, should_start_fetch) =
    cache_worker_state.ensure_single_fetch_with_waiter(state.cache, reply, Nil)
  let next_state = State(cache: cache)

  case should_start_fetch && can_fetch {
    True -> #(next_state, [StartFetch])
    False -> #(next_state, [])
  }
}

pub fn on_tick(
  state: State,
  now_ns: Int,
  can_fetch: Bool,
) -> #(State, List(Command)) {
  let commands = [ScheduleTick(refresh_interval_ms)]

  case
    can_fetch
    && cache_worker_state.single_is_stale(
      state.cache,
      now_ns,
      refresh_interval_ms,
    )
  {
    True -> {
      let #(next_state, refresh_commands) = start_fetch_if_idle(state)
      #(next_state, list.append(refresh_commands, commands))
    }
    False -> #(state, commands)
  }
}

pub fn on_fetch_completed(
  state: State,
  fetched_at_ns: Int,
  result: Reply,
) -> #(State, List(Command)) {
  let #(cache, fetch_outcome) =
    cache_worker_state.finish_single_fetch(
      state.cache,
      fetched_at_ns,
      result,
      Nil,
    )
  let next_state = State(cache: cache)
  let waiters = cache_worker_support.fetch_outcome_waiters(fetch_outcome)

  case result {
    Ok(config) -> #(
      next_state,
      list.map(waiters, fn(reply) { Reply(reply, Ok(config)) }),
    )
    Error(err) -> {
      #(next_state, [
        LogRefreshError(err),
        ..list.map(waiters, fn(reply) { Reply(reply, Error(err)) })
      ])
    }
  }
}

pub fn cache_is_stale(state: State, now_ns: Int) -> Bool {
  cache_worker_state.single_is_stale(state.cache, now_ns, refresh_interval_ms)
}

fn start_fetch_if_idle(state: State) -> #(State, List(Command)) {
  let #(cache, should_start_fetch) =
    cache_worker_state.ensure_single_fetch_if_idle(state.cache, Nil)
  let next_state = State(cache: cache)

  case should_start_fetch {
    True -> #(next_state, [StartFetch])
    False -> #(next_state, [])
  }
}
