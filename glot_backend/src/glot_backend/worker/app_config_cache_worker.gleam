import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import gleam/string
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_handlers
import glot_backend/effect/error
import glot_backend/erlang
import glot_backend/server_mode
import pog
import wisp

const call_timeout_ms = 5000

const refresh_interval_ms = 60_000

pub type Message {
  GetConfig(reply: process.Subject(Result(dynamic_config.DynamicConfig, error.DbQueryError)))
  Refresh(reply: process.Subject(Result(dynamic_config.DynamicConfig, error.DbQueryError)))
  Tick
  RefreshCompleted(
    fetched_at_ns: Int,
    result: Result(dynamic_config.DynamicConfig, error.DbQueryError),
  )
}

type InFlight {
  InFlight(
    waiters: List(
      process.Subject(Result(dynamic_config.DynamicConfig, error.DbQueryError)),
    ),
  )
}

pub type FetchHandlers {
  FetchHandlers(
    fetch_config: fn() -> Result(dynamic_config.DynamicConfig, error.DbQueryError),
    now_ns: fn() -> Int,
  )
}

type CacheEntry {
  CacheEntry(config: dynamic_config.DynamicConfig, refreshed_at_ns: Int)
}

type State {
  State(
    subject: process.Subject(Message),
    server_mode_subject: process.Subject(server_mode.Message),
    fetch_handlers: FetchHandlers,
    cache_entry: option.Option(CacheEntry),
    in_flight: option.Option(InFlight),
  )
}

pub fn start(
  name: process.Name(Message),
  db: pog.Connection,
  server_mode_subject: process.Subject(server_mode.Message),
) {
  start_with_handlers(
    name,
    server_mode_subject,
    FetchHandlers(
      fetch_config: fn() {
        app_config_handlers.new(db).list_entries()
        |> result.try(fn(entries) {
          dynamic_config.from_entries(entries)
          |> result.map_error(error.DbQueryError)
        })
      },
      now_ns: erlang.perf_counter_ns,
    ),
  )
}

pub fn start_with_handlers(
  name: process.Name(Message),
  server_mode_subject: process.Subject(server_mode.Message),
  fetch_handlers: FetchHandlers,
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject: subject,
        server_mode_subject: server_mode_subject,
        fetch_handlers: fetch_handlers,
        cache_entry: option.None,
        in_flight: option.None,
      )
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
  db: pog.Connection,
  server_mode_subject: process.Subject(server_mode.Message),
) {
  supervision.worker(fn() { start(name, db, server_mode_subject) })
}

pub fn get_config(
  subject: process.Subject(Message),
) -> Result(dynamic_config.DynamicConfig, error.DbQueryError) {
  process.call(subject, call_timeout_ms, GetConfig)
}

pub fn refresh(
  subject: process.Subject(Message),
) -> Result(dynamic_config.DynamicConfig, error.DbQueryError) {
  process.call(subject, call_timeout_ms, Refresh)
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    GetConfig(reply) -> {
      let now_ns = state.fetch_handlers.now_ns()
      let #(next_state, maybe_result) = lookup_config(state, now_ns, reply)

      case maybe_result {
        Ok(config) -> {
          process.send(reply, Ok(config))
          actor.continue(next_state)
        }
        Error(Nil) -> actor.continue(next_state)
      }
    }
    Refresh(reply) ->
      actor.continue(
        state
        |> ensure_fetch_started()
        |> enqueue_waiter(reply),
      )
    Tick -> {
      let _ = process.send_after(state.subject, refresh_interval_ms, Tick)
      case should_schedule_refreshes(state) {
        True ->
          actor.continue(
            case cache_is_stale(state, state.fetch_handlers.now_ns()) {
              True -> ensure_fetch_started(state)
              False -> state
            },
          )
        False -> actor.continue(state)
      }
    }
    RefreshCompleted(fetched_at_ns, result) ->
      actor.continue(complete_fetch(state, fetched_at_ns, result))
  }
}

fn lookup_config(
  state: State,
  now_ns: Int,
  reply: process.Subject(Result(dynamic_config.DynamicConfig, error.DbQueryError)),
) -> #(State, Result(dynamic_config.DynamicConfig, Nil)) {
  case state.cache_entry {
    option.Some(cache_entry) -> {
      let next_state = case is_stale(cache_entry, now_ns) {
        True -> maybe_start_stale_refresh(state)
        False -> state
      }
      #(next_state, Ok(cache_entry.config))
    }
    option.None ->
      case state.in_flight {
        option.Some(_) -> #(enqueue_waiter(state, reply), Error(Nil))
        option.None -> #(
          state
            |> ensure_fetch_started()
            |> enqueue_waiter(reply),
          Error(Nil),
        )
      }
  }
}

fn maybe_start_stale_refresh(state: State) -> State {
  case should_schedule_refreshes(state) {
    True -> ensure_fetch_started(state)
    False -> state
  }
}

fn cache_is_stale(state: State, now_ns: Int) -> Bool {
  case state.cache_entry {
    option.Some(cache_entry) -> is_stale(cache_entry, now_ns)
    option.None -> True
  }
}

fn ensure_fetch_started(state: State) -> State {
  case state.in_flight {
    option.Some(_) -> state
    option.None -> {
      let subject = state.subject
      let fetch_handlers = state.fetch_handlers

      let _ =
        process.spawn_unlinked(fn() {
          let result = fetch_handlers.fetch_config()
          let fetched_at_ns = fetch_handlers.now_ns()
          process.send(subject, RefreshCompleted(fetched_at_ns:, result: result))
        })

      State(..state, in_flight: option.Some(InFlight(waiters: [])))
    }
  }
}

fn enqueue_waiter(
  state: State,
  reply: process.Subject(Result(dynamic_config.DynamicConfig, error.DbQueryError)),
) -> State {
  let in_flight = case state.in_flight {
    option.Some(in_flight) -> in_flight
    option.None -> InFlight(waiters: [])
  }

  State(
    ..state,
    in_flight: option.Some(InFlight(waiters: [reply, ..in_flight.waiters])),
  )
}

fn complete_fetch(
  state: State,
  fetched_at_ns: Int,
  result: Result(dynamic_config.DynamicConfig, error.DbQueryError),
) -> State {
  let in_flight = case state.in_flight {
    option.Some(in_flight) -> in_flight
    option.None -> InFlight(waiters: [])
  }

  let next_state = State(..state, in_flight: option.None)

  case result {
    Ok(config) -> {
      let next_state =
        State(
          ..next_state,
          cache_entry: option.Some(CacheEntry(config:, refreshed_at_ns: fetched_at_ns)),
        )
      reply_waiters(in_flight.waiters, Ok(config))
      next_state
    }
    Error(err) -> {
      wisp.log_warning(
        "Failed to refresh app config cache: " <> string.inspect(err),
      )
      reply_waiters(in_flight.waiters, Error(err))
      next_state
    }
  }
}

fn should_schedule_refreshes(state: State) -> Bool {
  case server_mode.get_mode(state.server_mode_subject) {
    server_mode.ShuttingDown -> False
    _ -> True
  }
}

fn reply_waiters(
  waiters: List(process.Subject(Result(dynamic_config.DynamicConfig, error.DbQueryError))),
  result: Result(dynamic_config.DynamicConfig, error.DbQueryError),
) -> Nil {
  list.each(waiters, fn(reply) { process.send(reply, result) })
}

fn is_stale(entry: CacheEntry, now_ns: Int) -> Bool {
  now_ns - entry.refreshed_at_ns >= ms_to_ns(refresh_interval_ms)
}

fn ms_to_ns(value_ms: Int) -> Int {
  value_ms * 1_000_000
}
