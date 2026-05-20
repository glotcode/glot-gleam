import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import glot_backend/migration_runner
import glot_backend/server_mode
import glot_backend/worker/tick_worker_support
import pog
import wisp

const retry_interval_ms = 5000

pub type Message {
  Tick
  StartupDbCompleted(Result(#(List(String), List(String)), String))
}

type State {
  State(
    subject: process.Subject(Message),
    db: pog.Connection,
    migrations_dir: String,
    seeds_dir: String,
    server_mode_subject: process.Subject(server_mode.Message),
    in_flight: Bool,
  )
}

pub fn start(
  db: pog.Connection,
  migrations_dir: String,
  seeds_dir: String,
  server_mode_subject: process.Subject(server_mode.Message),
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject:,
        db:,
        migrations_dir: migrations_dir,
        seeds_dir: seeds_dir,
        server_mode_subject: server_mode_subject,
        in_flight: False,
      )
    let _ = process.send(subject, Tick)
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(
  db: pog.Connection,
  migrations_dir: String,
  seeds_dir: String,
  server_mode_subject: process.Subject(server_mode.Message),
) {
  supervision.worker(fn() {
    start(db, migrations_dir, seeds_dir, server_mode_subject)
  })
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
  case
    state.in_flight
    || server_mode.get_mode(state.server_mode_subject) == server_mode.Running
  {
    True -> state
    False -> {
      let subject = state.subject
      let db = state.db
      let migrations_dir = state.migrations_dir
      let seeds_dir = state.seeds_dir

      let _ =
        process.spawn_unlinked(fn() {
          let result =
            migration_runner.run_pending(db, migrations_dir)
            |> result.try(fn(applied_versions) {
              migration_runner.run_pending_seeds(db, seeds_dir)
              |> result.map(fn(applied_seeds) {
                #(applied_versions, applied_seeds)
              })
            })
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

      server_mode.enter_running(state.server_mode_subject)
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
