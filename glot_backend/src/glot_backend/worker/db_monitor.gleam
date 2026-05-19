import gleam/dynamic/decode
import gleam/erlang/process
import gleam/int
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import gleam/string
import glot_backend/helpers/db_helpers
import glot_backend/server_mode
import glot_backend/worker/tick_worker_support
import pog
import wisp

const health_check_interval_ms = 1000

const max_consecutive_failures = 5

pub type Message {
  Tick
}

type State {
  State(
    subject: process.Subject(Message),
    db: pog.Connection,
    server_mode_subject: process.Subject(server_mode.Message),
    consecutive_failures: Int,
  )
}

pub fn start(
  db: pog.Connection,
  server_mode_subject: process.Subject(server_mode.Message),
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(subject:, db:, server_mode_subject:, consecutive_failures: 0)
    let _ = process.send(subject, Tick)
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(
  db: pog.Connection,
  server_mode_subject: process.Subject(server_mode.Message),
) {
  supervision.worker(fn() { start(db, server_mode_subject) })
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Tick -> {
      case server_mode.get_mode(state.server_mode_subject) {
        server_mode.ShuttingDown -> actor.continue(state)
        _ -> continue_monitoring(state)
      }
    }
  }
}

fn continue_monitoring(state: State) -> actor.Next(State, Message) {
  let next_state = case health_check(state.db) {
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
        <> string.inspect(err),
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

fn health_check(db: pog.Connection) -> Result(Nil, pog.QueryError) {
  pog.query("SELECT 1")
  |> pog.timeout(db_helpers.default_query_timeout_ms())
  |> pog.returning(ping_decoder())
  |> pog.execute(db)
  |> result.map(fn(_) { Nil })
}

fn ping_decoder() -> decode.Decoder(Int) {
  use value <- decode.field(0, decode.int)
  decode.success(value)
}
