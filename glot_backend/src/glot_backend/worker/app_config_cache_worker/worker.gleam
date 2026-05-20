import gleam/erlang/process
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import gleam/string
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_handlers
import glot_backend/effect/error/db_error
import glot_backend/erlang
import glot_backend/helpers/db_helpers
import glot_backend/server_mode
import glot_backend/worker/app_config_cache_worker/core
import pog
import wisp

const call_timeout_ms = 5000

pub type Message {
  GetConfig(
    reply: process.Subject(
      Result(dynamic_config.DynamicConfig, db_error.DbQueryError),
    ),
  )
  Refresh(
    reply: process.Subject(
      Result(dynamic_config.DynamicConfig, db_error.DbQueryError),
    ),
  )
  Tick
  RefreshCompleted(
    fetched_at_ns: Int,
    result: Result(dynamic_config.DynamicConfig, db_error.DbQueryError),
  )
}

pub type Deps {
  Deps(
    fetch_config: fn() ->
      Result(dynamic_config.DynamicConfig, db_error.DbQueryError),
    now_ns: fn() -> Int,
  )
}

type State {
  State(
    subject: process.Subject(Message),
    server_mode_subject: process.Subject(server_mode.Message),
    deps: Deps,
    core: core.State,
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
    Deps(
      fetch_config: fn() {
        app_config_handlers.new(db_helpers.new(db)).list_entries()
        |> result.try(fn(entries) {
          dynamic_config.from_entries(entries)
          |> result.map_error(db_error.DbQueryError)
        })
      },
      now_ns: erlang.perf_counter_ns,
    ),
  )
}

pub fn start_with_handlers(
  name: process.Name(Message),
  server_mode_subject: process.Subject(server_mode.Message),
  deps: Deps,
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject: subject,
        server_mode_subject: server_mode_subject,
        deps: deps,
        core: core.new(),
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
) -> Result(dynamic_config.DynamicConfig, db_error.DbQueryError) {
  process.call(subject, call_timeout_ms, GetConfig)
}

pub fn refresh(
  subject: process.Subject(Message),
) -> Result(dynamic_config.DynamicConfig, db_error.DbQueryError) {
  process.call(subject, call_timeout_ms, Refresh)
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    GetConfig(reply) -> {
      let now_ns = state.deps.now_ns()
      let #(next_core, commands) =
        core.on_get(state.core, reply, now_ns, can_fetch(state))
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
    Refresh(reply) -> {
      let #(next_core, commands) =
        core.on_refresh_requested(state.core, reply, can_fetch(state))
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
    Tick -> {
      let #(next_core, commands) =
        core.on_tick(state.core, state.deps.now_ns(), can_fetch(state))
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
    RefreshCompleted(fetched_at_ns, result) -> {
      let #(next_core, commands) =
        core.on_fetch_completed(state.core, fetched_at_ns, result)
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
  }
}

fn run_commands(state: State, commands: List(core.Command)) -> State {
  list.fold(commands, state, fn(state: State, command) {
    case command {
      core.ScheduleTick(delay_ms) -> {
        let _ = process.send_after(state.subject, delay_ms, Tick)
        state
      }
      core.StartFetch -> {
        let subject = state.subject
        let deps = state.deps
        let _ =
          process.spawn_unlinked(fn() {
            let result = deps.fetch_config()
            let fetched_at_ns = deps.now_ns()
            process.send(
              subject,
              RefreshCompleted(fetched_at_ns:, result: result),
            )
          })
        state
      }
      core.Reply(reply, result) -> {
        process.send(reply, result)
        state
      }
      core.LogRefreshError(err) -> {
        wisp.log_warning(
          "Failed to refresh app config cache: " <> string.inspect(err),
        )
        state
      }
    }
  })
}

fn can_fetch(state: State) -> Bool {
  server_mode.get_mode(state.server_mode_subject) == server_mode.Running
}
