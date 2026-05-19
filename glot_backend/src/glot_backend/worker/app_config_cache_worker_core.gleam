import gleam/erlang/process
import gleam/list
import gleam/option
import glot_backend/dynamic_config
import glot_backend/effect/error/db_error
import glot_backend/worker/cache_worker_support

pub const refresh_interval_ms = 60_000

pub type Reply =
  Result(dynamic_config.DynamicConfig, db_error.DbQueryError)

pub type State {
  State(
    cache_entry: option.Option(
      cache_worker_support.CacheEntry(dynamic_config.DynamicConfig),
    ),
    in_flight: option.Option(cache_worker_support.InFlight(Reply, Nil)),
  )
}

pub type Command {
  ScheduleTick(delay_ms: Int)
  StartFetch
  Reply(reply_to: process.Subject(Reply), result: Reply)
  LogRefreshError(err: db_error.DbQueryError)
}

pub fn new() -> State {
  State(cache_entry: option.None, in_flight: option.None)
}

pub fn on_get_config(
  state: State,
  reply: process.Subject(Reply),
  now_ns: Int,
  can_fetch: Bool,
) -> #(State, List(Command)) {
  case
    cache_worker_support.single_lookup(
      state.cache_entry,
      state.in_flight,
      reply,
      now_ns,
      refresh_interval_ms,
      can_fetch,
      Ok,
      Ok(dynamic_config.empty()),
      Nil,
    )
  {
    cache_worker_support.ReplyNow(result, start_refresh) -> {
      let commands = case start_refresh && can_fetch && state.in_flight == option.None {
        True -> [StartFetch]
        False -> []
      }
      let next_state = case commands {
        [StartFetch] ->
          State(..state, in_flight: option.Some(cache_worker_support.new_in_flight(Nil)))
        _ -> state
      }
      #(next_state, [Reply(reply, result), ..commands])
    }
    cache_worker_support.AwaitFetch(in_flight, start_fetch) -> {
      let next_state = State(..state, in_flight: option.Some(in_flight))
      let commands = case start_fetch {
        True -> [StartFetch]
        False -> []
      }
      #(next_state, commands)
    }
  }
}

pub fn on_refresh(
  state: State,
  reply: process.Subject(Reply),
  can_fetch: Bool,
) -> #(State, List(Command)) {
  let in_flight = cache_worker_support.single_in_flight(state.in_flight, Nil)
  let next_state =
    State(
      ..state,
      in_flight: option.Some(cache_worker_support.with_waiter(in_flight, reply)),
    )

  case state.in_flight, can_fetch {
    option.None, True -> #(next_state, [StartFetch])
    _, _ -> #(next_state, [])
  }
}

pub fn on_tick(
  state: State,
  now_ns: Int,
  can_fetch: Bool,
) -> #(State, List(Command)) {
  let commands = [ScheduleTick(refresh_interval_ms)]

  case can_fetch, state.in_flight, cache_is_stale(state, now_ns) {
    True, option.None, True -> #(
      State(..state, in_flight: option.Some(cache_worker_support.new_in_flight(Nil))),
      [StartFetch, ..commands],
    )
    _, _, _ -> #(state, commands)
  }
}

pub fn on_refresh_completed(
  state: State,
  fetched_at_ns: Int,
  result: Reply,
) -> #(State, List(Command)) {
  let in_flight = cache_worker_support.single_in_flight(state.in_flight, Nil)
  let next_state = State(..state, in_flight: option.None)

  case result {
    Ok(config) -> {
      let assert option.Some(cache_entry) =
        cache_worker_support.cache_result(fetched_at_ns, result)
      #(
        State(..next_state, cache_entry: option.Some(cache_entry)),
        list.map(in_flight.waiters, fn(reply) { Reply(reply, Ok(config)) }),
      )
    }
    Error(err) -> #(
      next_state,
      [
        LogRefreshError(err),
        ..list.map(in_flight.waiters, fn(reply) { Reply(reply, Error(err)) }),
      ],
    )
  }
}

pub fn cache_is_stale(state: State, now_ns: Int) -> Bool {
  case state.cache_entry {
    option.Some(cache_entry) ->
      cache_worker_support.is_stale(cache_entry, now_ns, refresh_interval_ms)
    option.None -> True
  }
}
