import gleam/erlang/process
import gleam/json
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/domain/job/job_manager_domain
import glot_backend/domain/job/periodic_job_manager_domain
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/interpreter
import glot_backend/effect/program_state
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/helpers/db_helpers
import glot_backend/job_tracker
import glot_backend/log
import glot_backend/server_mode
import glot_backend/sql
import glot_backend/worker/app_config_cache_worker
import glot_backend/worker/language_version_cache_worker
import glot_core/helpers/dict_helpers
import glot_core/helpers/list_helpers
import glot_core/job/job_model
import pog
import wisp
import youid/uuid.{type Uuid}

const idle_poll_ms = 1000

pub type Message {
  Tick
  AttemptCompleted(pid: process.Pid, log_entry: JobLogEntry)
  AttemptTimedOut(pid: process.Pid)
}

type ActiveAttempt {
  ActiveAttempt(
    pid: process.Pid,
    timer: process.Timer,
    job: job_model.Job,
    ctx: context.Context,
  )
}

type State {
  State(
    subject: process.Subject(Message),
    db: pog.Connection,
    config: context.Config,
    regexes: context.Regexes,
    job_tracker_subject: process.Subject(job_tracker.Message),
    server_mode_subject: process.Subject(server_mode.Message),
    app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
    language_version_cache_subject: process.Subject(
      language_version_cache_worker.Message,
    ),
    active_attempt: Option(ActiveAttempt),
  )
}

pub fn start(
  db: pog.Connection,
  config: context.Config,
  regexes: context.Regexes,
  job_tracker_subject: process.Subject(job_tracker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject: subject,
        db: db,
        config: config,
        regexes: regexes,
        job_tracker_subject: job_tracker_subject,
        server_mode_subject: server_mode_subject,
        app_config_cache_subject: app_config_cache_subject,
        language_version_cache_subject: language_version_cache_subject,
        active_attempt: option.None,
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
  config: context.Config,
  regexes: context.Regexes,
  job_tracker_subject: process.Subject(job_tracker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
) {
  supervision.worker(fn() {
    start(
      db,
      config,
      regexes,
      job_tracker_subject,
      server_mode_subject,
      app_config_cache_subject,
      language_version_cache_subject,
    )
  })
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    Tick ->
      case server_mode.get_mode(state.server_mode_subject) {
        server_mode.Maintenance -> actor.continue(state)
        server_mode.ShuttingDown -> actor.continue(state)
        server_mode.Running -> {
          let #(next_state, maybe_delay) = run_once(state)
          schedule_next_tick(next_state.subject, maybe_delay)
          actor.continue(next_state)
        }
      }
    AttemptCompleted(pid, log_entry) -> {
      let next_state = finish_attempt(state, pid, log_entry)
      actor.continue(next_state)
    }
    AttemptTimedOut(pid) -> {
      let next_state = timeout_attempt(state, pid)
      actor.continue(next_state)
    }
  }
}

fn schedule_next_tick(
  subject: process.Subject(Message),
  maybe_delay: Option(Int),
) -> Nil {
  case maybe_delay {
    option.Some(delay) -> {
      let _ = process.send_after(subject, delay, Tick)
      Nil
    }
    option.None -> Nil
  }
}

fn run_once(state: State) -> #(State, Option(Int)) {
  case state.active_attempt {
    option.Some(_) -> #(state, option.None)
    option.None -> {
      let effect_runtime =
        runtime.new(
          state.db,
          state.app_config_cache_subject,
          state.language_version_cache_subject,
        )
      let ctx = context_from_state(state, option.None)

      let #(periodic_result, _) =
        periodic_job_manager_domain.enqueue_next_due_periodic_job(ctx)
        |> interpreter.run(effect_runtime, ctx)

      case periodic_result {
        Ok(True) -> #(state, option.Some(0))
        Ok(False) -> claim_and_process_job(state, effect_runtime, ctx)
        Error(err) -> {
          wisp.log_error(
            "Failed to enqueue periodic job: " <> string.inspect(err),
          )
          claim_and_process_job(state, effect_runtime, ctx)
        }
      }
    }
  }
}

fn claim_and_process_job(
  state: State,
  effect_runtime: runtime.Runtime,
  ctx: context.Context,
) -> #(State, Option(Int)) {
  let #(result, _) =
    job_manager_domain.claim_next_job(ctx)
    |> interpreter.run(effect_runtime, ctx)

  case result {
    Ok(maybe_job) ->
      case maybe_job {
        option.Some(job) -> #(start_attempt(state, job), option.None)
        option.None -> #(state, option.Some(idle_poll_ms))
      }
    Error(err) -> {
      wisp.log_error("Failed to claim job: " <> string.inspect(err))
      #(state, option.Some(idle_poll_ms))
    }
  }
}

fn start_attempt(state: State, job: job_model.Job) -> State {
  let ctx = context_from_state(state, job.request_id)
  let subject = state.subject
  let db = state.db
  let app_config_cache_subject = state.app_config_cache_subject
  let language_version_cache_subject = state.language_version_cache_subject
  job_tracker.job_started(state.job_tracker_subject)

  let pid =
    process.spawn_unlinked(fn() {
      let effect_runtime =
        runtime.new(
          db,
          app_config_cache_subject,
          language_version_cache_subject,
        )
      let #(result, program_state) =
        job_manager_domain.process_job(ctx, job)
        |> interpreter.run(effect_runtime, ctx)

      process.send(
        subject,
        AttemptCompleted(
          process.self(),
          prepare_log_entry(ctx, program_state, job, result),
        ),
      )
    })

  let timeout_timer =
    process.send_after(
      subject,
      job.timeout_seconds * 1000,
      AttemptTimedOut(pid),
    )

  State(
    ..state,
    active_attempt: option.Some(ActiveAttempt(pid, timeout_timer, job, ctx)),
  )
}

fn finish_attempt(
  state: State,
  pid: process.Pid,
  log_entry: JobLogEntry,
) -> State {
  case state.active_attempt {
    option.Some(active) if active.pid == pid -> {
      let _ = process.cancel_timer(active.timer)
      job_tracker.job_finished(state.job_tracker_subject)
      insert_job_log(state.db, log_entry)
      let _ = process.send(state.subject, Tick)
      State(..state, active_attempt: option.None)
    }
    _ -> state
  }
}

fn timeout_attempt(state: State, pid: process.Pid) -> State {
  case state.active_attempt {
    option.Some(active) if active.pid == pid -> {
      process.kill(active.pid)
      let effect_runtime =
        runtime.new(
          state.db,
          state.app_config_cache_subject,
          state.language_version_cache_subject,
        )
      let #(result, _) =
        job_manager_domain.timeout_job(active.ctx, active.job)
        |> interpreter.run(effect_runtime, active.ctx)

      case result {
        Ok(_) -> Nil
        Error(err) ->
          wisp.log_error("Failed to time out job: " <> string.inspect(err))
      }

      let timeout_log_entry = prepare_timeout_log_entry(active.ctx, active.job)

      job_tracker.job_finished(state.job_tracker_subject)
      insert_job_log(state.db, timeout_log_entry)
      let _ = process.send(state.subject, Tick)
      State(..state, active_attempt: option.None)
    }
    _ -> state
  }
}

fn prepare_timeout_log_entry(
  ctx: context.Context,
  job: job_model.Job,
) -> JobLogEntry {
  JobLogEntry(
    ..prepare_log_entry(
      ctx,
      program_state.new_state(),
      job,
      Error(error.ValidationError("timeout_exceeded")),
    ),
    created_at: basic_handlers.system_time(),
  )
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
    debug: state.debug_fields,
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
