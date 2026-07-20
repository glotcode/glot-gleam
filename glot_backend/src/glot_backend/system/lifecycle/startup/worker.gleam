import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import glot_backend/system/lifecycle/server_mode/model
import glot_backend/system/lifecycle/server_mode/ports/controller.{
  type Controller,
}
import glot_backend/system/lifecycle/startup/ports/runner.{type Runner}
import glot_backend/system/worker/tick_support as tick_worker_support
import wisp

const retry_interval_ms = 5000

pub type Message {
  Tick
  StartupDbCompleted(Result(#(List(String), List(String)), String))
}

type State {
  State(
    subject: process.Subject(Message),
    runner: Runner,
    server_mode: Controller,
    in_flight: Bool,
  )
}

pub fn start(runner: Runner, server_mode: Controller) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state = State(subject:, runner:, server_mode:, in_flight: False)
    let _ = process.send(subject, Tick)
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(runner: Runner, server_mode: Controller) {
  supervision.worker(fn() { start(runner, server_mode) })
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Tick -> actor.continue(maybe_start_migrations(state))
    StartupDbCompleted(result) ->
      actor.continue(handle_migration_result(state, result))
  }
}

fn maybe_start_migrations(state: State) -> State {
  case state.in_flight || state.server_mode.current() == model.Running {
    True -> state
    False -> {
      let subject = state.subject
      let runner = state.runner

      let _ =
        process.spawn_unlinked(fn() {
          let result = runner.run()
          process.send(subject, StartupDbCompleted(result))
        })

      State(..state, in_flight: True)
    }
  }
}

fn handle_migration_result(
  state: State,
  result: Result(#(List(String), List(String)), String),
) -> State {
  case result {
    Ok(#(applied_versions, applied_seeds)) -> {
      case applied_versions {
        [] -> wisp.log_info("No pending migrations")
        _ ->
          wisp.log_info(
            "Applied migrations: " <> string_from_versions(applied_versions),
          )
      }
      case applied_seeds {
        [] -> Nil
        _ ->
          wisp.log_info(
            "Applied seeds: " <> string_from_versions(applied_seeds),
          )
      }

      state.server_mode.enter_running()
      wisp.log_info("Database startup SQL completed, server is running")
      State(..state, in_flight: False)
    }
    Error(err) -> {
      wisp.log_error("Database migrations failed: " <> err)
      wisp.log_warning(
        "Retrying database migrations in "
        <> int.to_string(retry_interval_ms)
        <> "ms",
      )
      let _ =
        tick_worker_support.schedule(state.subject, retry_interval_ms, Tick)
      State(..state, in_flight: False)
    }
  }
}

fn string_from_versions(versions: List(String)) -> String {
  case versions {
    [] -> ""
    [first, ..rest] ->
      list.fold(rest, first, fn(acc, version) { acc <> ", " <> version })
  }
}
