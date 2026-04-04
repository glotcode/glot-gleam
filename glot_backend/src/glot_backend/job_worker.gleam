import gleam/erlang/process
import gleam/json
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/domain/job/job_manager_domain
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/effect/program_state
import glot_backend/erlang
import glot_backend/helpers/db_helpers
import glot_backend/log
import glot_backend/sql
import glot_core/helpers/dict_helpers
import glot_core/helpers/list_helpers
import glot_core/job/job_model
import pog
import wisp
import youid/uuid.{type Uuid}

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
        job_model.NoJobs -> idle_poll_ms
        job_model.JobProcessed -> 0
      }

      let _ = process.send_after(state.subject, delay, Tick)
      actor.continue(state)
    }
  }
}

fn run_once(state: State) -> job_model.Outcome {
  let handlers = handlers.new(state.db)
  let ctx = context_from_state(state, option.None)

  let #(result, _) =
    job_manager_domain.claim_next_job(ctx)
    |> interpreter.run(handlers, option.Some(state.db), ctx)

  case result {
    Ok(maybe_job) -> {
      case maybe_job {
        option.Some(job) -> {
          process_job(state, job)
          job_model.JobProcessed
        }
        option.None -> job_model.NoJobs
      }
    }
    Error(err) -> {
      wisp.log_error("Failed to claim job: " <> string.inspect(err))
      job_model.NoJobs
    }
  }
}

fn process_job(state: State, job: job_model.Job) -> Nil {
  let handlers = handlers.new(state.db)
  let ctx = context_from_state(state, job.request_id)
  let #(result, program_state) =
    job_manager_domain.process_job(ctx, job)
    |> interpreter.run(handlers, option.Some(state.db), ctx)

  let log_entry = prepare_log_entry(ctx, program_state, job, result)
  insert_job_log(state.db, log_entry)
}

fn prepare_log_entry(
  ctx: context.Context,
  state: program_state.State,
  job: job_model.Job,
  result: Result(Nil, error.Error),
) -> JobLogEntry {
  let id = basic_handlers.uuid_v7(ctx.timestamp)
  let duration_ns = erlang.perf_counter_ns() - ctx.started_at

  let error = case result {
    Ok(_) -> option.None
    Error(err) -> option.Some(err)
  }

  JobLogEntry(
    id: id,
    request_id: job.request_id,
    job_id: job.id,
    job_type: job.job_type,
    attempt: job.attempts,
    created_at: ctx.timestamp,
    duration_ns: duration_ns,
    info: state.info_fields,
    warnings: state.warning_fields,
    debug: log.new(),
    // TODO: state.debug_fields,
    error: error,
    effects: state.effect_measurements,
  )
}

fn context_from_state(
  state: State,
  request_id: option.Option(Uuid),
) -> context.Context {
  let now = basic_handlers.system_time()

  context.Context(
    config: state.config,
    regexes: state.regexes,
    request_id: request_id
      |> option.lazy_unwrap(fn() { basic_handlers.uuid_v7(now) }),
    started_at: erlang.perf_counter_ns(),
    timestamp: now,
    client_info: context.empty_client_info(),
  )
}

pub type JobLogEntry {
  JobLogEntry(
    id: Uuid,
    request_id: Option(Uuid),
    job_id: Uuid,
    job_type: job_model.JobType,
    attempt: Int,
    created_at: Timestamp,
    duration_ns: Int,
    info: log.Fields,
    warnings: log.Fields,
    debug: log.Fields,
    error: option.Option(error.Error),
    effects: List(effect_trace.EffectMeasurement),
  )
}

fn insert_job_log(db: pog.Connection, entry: JobLogEntry) -> Nil {
  let query =
    sql.insert_job_log(
      id: uuid.to_bit_array(entry.id),
      request_id: entry.request_id |> option.map(uuid.to_bit_array),
      job_id: uuid.to_bit_array(entry.job_id),
      job_type: job_model.job_type_to_string(entry.job_type),
      attempt: entry.attempt,
      created_at: entry.created_at,
      duration_ns: entry.duration_ns,
      info: entry.info
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      warnings: entry.warnings
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      debug: entry.debug
        |> dict_helpers.non_empty_dict
        |> option.map(log.encode_fields)
        |> option.map(json.to_string),
      error: entry.error
        |> option.map(encode_error)
        |> option.map(json.to_string),
      effects: entry.effects
        |> list_helpers.non_empty_list
        |> option.map(effect_trace.encode_effect_measurements)
        |> option.map(json.to_string),
    )
  let res = db_helpers.execute(db, query, fn(err) { string.inspect(err) })

  case res {
    Ok(_) -> Nil
    Error(err) -> wisp.log_error("Failed to insert log entry: " <> err)
  }
}

fn encode_error(err: error.Error) -> json.Json {
  json.object([
    #("message", json.string(error.to_string(err))),
  ])
}
