import gleam/erlang/process
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/timestamp
import glot_backend/context
import glot_backend/domain/job/job_manager_domain
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/erlang
import glot_backend/job
import pog
import wisp
import youid/uuid

const idle_poll_ms = 1000

pub type Message {
  Tick
}

type State {
  State(
    subject: process.Subject(Message),
    db: pog.Connection,
    config: context.Config,
    regexes: context.Regexes,
  )
}

pub fn start(
  db: pog.Connection,
  config: context.Config,
  regexes: context.Regexes,
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state = State(subject:, db:, config:, regexes:)
    let _ = process.send(subject, Tick)
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(
  db: pog.Connection,
  config: context.Config,
  regexes: context.Regexes,
) {
  supervision.worker(fn() { start(db, config, regexes) })
}

fn handle_message(state: State, message: Message) -> actor.Next(State, Message) {
  case message {
    Tick -> {
      let delay = case run_once(state) {
        job.NoJobs -> idle_poll_ms
        job.JobProcessed -> 0
      }

      let _ = process.send_after(state.subject, delay, Tick)
      actor.continue(state)
    }
  }
}

fn run_once(state: State) -> job.Outcome {
  let ctx = context_from_state(state)
  let handlers = handlers.new(state.db)
  let #(result, _) =
    job_manager_domain.process_next_job(ctx)
    |> interpreter.run(handlers, option.Some(state.db), ctx)

  // TODO: log to db
  case result {
    Ok(outcome) -> outcome
    Error(err) -> {
      wisp.log_error("Job worker failed: " <> string.inspect(err))
      job.JobProcessed
    }
  }
}

fn context_from_state(state: State) -> context.Context {
  context.Context(
    config: state.config,
    regexes: state.regexes,
    request_id: uuid.v7(),
    started_at: erlang.perf_counter_ns(),
    timestamp: timestamp.system_time(),
    client_info: context.empty_client_info(),
  )
}
