import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/timestamp
import glot_backend/context
import glot_backend/effect/error
import glot_backend/effect/core/core_effect
import glot_backend/effect/program_types
import glot_backend/effect/job/job_effect
import glot_backend/effect/interpreter
import glot_backend/effect/program
import glot_backend/email_message
import glot_backend/erlang
import glot_backend/job
import glot_backend/effect/handlers
import pog
import wisp
import youid/uuid

const idle_poll_ms = 1000

const base_backoff_seconds = 5

const max_backoff_seconds = 300

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
        True -> 0
        False -> idle_poll_ms
      }

      let State(subject:, ..) = state
      let _ = process.send_after(subject, delay, Tick)
      actor.continue(state)
    }
  }
}

fn run_once(state: State) -> Bool {
  let ctx = context_from_state(state)
  let State(db:, ..) = state
  let handlers = handlers.new(db)
  let #(result, _) =
    process_next_job(ctx)
    |> interpreter.run(handlers, option.Some(db), ctx)

  case result {
    Ok(processed_job) -> processed_job
    Error(err) -> {
      wisp.log_error("Job worker failed: " <> string.inspect(err))
      False
    }
  }
}

fn context_from_state(state: State) -> context.Context {
  let State(config:, regexes:, ..) = state
  context.Context(
    config: config,
    regexes: regexes,
    request_id: uuid.v7(),
    started_at: erlang.perf_counter_ns(),
    timestamp: timestamp.system_time(),
    client_info: context.ClientInfo(
      session_token: option.None,
      ip: option.None,
      user_agent: option.None,
    ),
  )
}

fn process_next_job(ctx: context.Context) -> program_types.Program(Bool) {
  use now <- program.and_then(core_effect.system_time())
  use maybe_job <- program.and_then(job_effect.db_get_next_job(
    now,
    job.Pending,
    job.Running,
  ))

  case maybe_job {
    option.None -> program.succeed(False)
    option.Some(next_job) ->
      process_job(ctx, next_job) |> program.map(fn(_) { True })
  }
}

fn process_job(
  ctx: context.Context,
  next_job: job.Job,
) -> program_types.Program(Nil) {
  case next_job {
    job.Job(
      job_type: job.SendEmailJob,
      payload: payload,
      ..,
    ) -> process_send_email_job(ctx, next_job, payload)
  }
}

fn process_send_email_job(
  ctx: context.Context,
  j: job.Job,
  payload: String,
) -> program_types.Program(Nil) {
  case json.parse(payload, email_message.decoder(ctx.regexes.is_email)) {
    Ok(message) -> {
      use send_result <- program.and_then(core_effect.send_email(message))
      use now <- program.and_then(core_effect.system_time())

      case send_result {
        Ok(_) -> job.done(j, now) |> job_effect.update
        Error(err) ->
          job.reschedule(
            j,
            add_seconds(now, backoff_seconds(j.attempts)),
            option.Some(send_email_error_to_string(err)),
            now,
          )
          |> job_effect.update
      }
    }
    Error(errors) -> {
      use now <- program.and_then(core_effect.system_time())
      job.reschedule(
        j,
        add_seconds(now, backoff_seconds(j.attempts)),
        option.Some("decode_error:" <> string.inspect(errors)),
        now,
      )
      |> job_effect.update
    }
  }
}

fn backoff_seconds(attempts: Int) -> Int {
  let exponent = int.max(attempts - 1, 0)
  let multiplier = power_of_two(exponent)
  int.min(base_backoff_seconds * multiplier, max_backoff_seconds)
}

fn power_of_two(exponent: Int) -> Int {
  case exponent <= 0 {
    True -> 1
    False -> 2 * power_of_two(exponent - 1)
  }
}

fn add_seconds(
  ts: timestamp.Timestamp,
  seconds_to_add: Int,
) -> timestamp.Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(seconds + seconds_to_add, nanos)
}

fn send_email_error_to_string(err: error.SendEmailError) -> String {
  case err {
    error.PublicSendEmailError(message) -> "send_email_public:" <> message
    error.InternalSendEmailError(message) -> "send_email_internal:" <> message
  }
}
