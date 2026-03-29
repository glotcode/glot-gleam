import gleam/erlang/process
import gleam/int
import gleam/json
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/timestamp
import glot_backend/context
import glot_backend/email_message
import glot_backend/job
import glot_backend/program
import glot_backend/program/handlers as program_handlers
import pog
import wisp
import youid/uuid.{type Uuid}

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
  let handlers = program_handlers.from_context(ctx)
  let #(result, _) = process_next_job(ctx) |> program.run(handlers)

  case result {
    Ok(processed_job) -> processed_job
    Error(err) -> {
      wisp.log_error("Job worker failed: " <> string.inspect(err))
      False
    }
  }
}

fn context_from_state(state: State) -> context.Context {
  let State(db:, config:, regexes:, ..) = state
  context.Context(
    db: db,
    config: config,
    regexes: regexes,
    timestamp: timestamp.system_time(),
    client_info: context.ClientInfo(
      session_token: option.None,
      ip: option.None,
      user_agent: option.None,
    ),
  )
}

fn process_next_job(ctx: context.Context) -> program.Program(Bool) {
  use now <- program.and_then(program.system_time())
  use maybe_job <- program.and_then(program.db_get_next_job(
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

fn process_job(ctx: context.Context, next_job: job.Job) -> program.Program(Nil) {
  case next_job {
    job.Job(
      id: id,
      job_type: job.SendEmailJob,
      payload: payload,
      attempts: attempts,
      ..,
    ) -> process_send_email_job(ctx, id, payload, attempts)
  }
}

fn process_send_email_job(
  ctx: context.Context,
  id: Uuid,
  payload: String,
  attempts: Int,
) -> program.Program(Nil) {
  case json.parse(payload, email_message.decoder(ctx.regexes.is_email)) {
    Ok(message) -> {
      use send_result <- program.and_then(program.attempt_send_email(message))
      use now <- program.and_then(program.system_time())

      case send_result {
        Ok(_) -> program.run_command(program.DbMarkJobDone(id, now))
        Error(err) ->
          program.run_command(program.DbRescheduleJob(
            id: id,
            run_at: add_seconds(now, backoff_seconds(attempts)),
            last_error: option.Some(send_email_error_to_string(err)),
            updated_at: now,
          ))
      }
    }
    Error(errors) -> {
      use now <- program.and_then(program.system_time())
      program.run_command(program.DbRescheduleJob(
        id: id,
        run_at: add_seconds(now, backoff_seconds(attempts)),
        last_error: option.Some("decode_error:" <> string.inspect(errors)),
        updated_at: now,
      ))
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

fn send_email_error_to_string(err: program.SendEmailError) -> String {
  case err {
    program.PublicSendEmailError(message) -> "send_email_public:" <> message
    program.InternalSendEmailError(message) -> "send_email_internal:" <> message
  }
}
