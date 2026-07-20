import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/otp/supervision
import glot_backend/system/lifecycle/database_health/ports/checker.{type Checker}
import glot_backend/system/lifecycle/server_mode/model
import glot_backend/system/lifecycle/server_mode/ports/controller.{
  type Controller,
}
import glot_backend/system/worker/tick_support as tick_worker_support
import wisp

const health_check_interval_ms = 1000

const max_consecutive_failures = 5

pub type Message {
  Tick
}

type State {
  State(
    subject: process.Subject(Message),
    checker: Checker,
    server_mode: Controller,
    consecutive_failures: Int,
  )
}

pub fn start(checker: Checker, server_mode: Controller) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(subject:, checker:, server_mode:, consecutive_failures: 0)
    let _ = process.send(subject, Tick)
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(checker: Checker, server_mode: Controller) {
  supervision.worker(fn() { start(checker, server_mode) })
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Tick -> {
      case state.server_mode.current() {
        model.ShuttingDown -> actor.continue(state)
        _ -> continue_monitoring(state)
      }
    }
  }
}

fn continue_monitoring(state: State) -> actor.Next(State, Message) {
  let next_state = case state.checker.check() {
    Ok(_) -> {
      case state.consecutive_failures > 0 {
        True ->
          wisp.log_info(
            "Database health check recovered after "
            <> int.to_string(state.consecutive_failures)
            <> " failed attempts",
          )
        False -> Nil
      }

      State(..state, consecutive_failures: 0)
    }
    Error(err) -> {
      let failures = state.consecutive_failures + 1
      wisp.log_error(
        "Database health check failed ("
        <> int.to_string(failures)
        <> "/"
        <> int.to_string(max_consecutive_failures)
        <> "): "
        <> err,
      )

      case failures >= max_consecutive_failures {
        True -> panic as "database health checks exceeded failure threshold"
        False -> State(..state, consecutive_failures: failures)
      }
    }
  }

  let _ =
    tick_worker_support.schedule(state.subject, health_check_interval_ms, Tick)
  actor.continue(next_state)
}
