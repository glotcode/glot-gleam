import gleam/erlang/process
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/string
import glot_backend/context
import glot_backend/domain/job/job_manager_domain
import glot_backend/domain/job/periodic_job_manager_domain
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/error/infra_error
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
import glot_backend/worker/job_worker_core as core
import glot_backend/worker/language_version_cache_worker
import glot_backend/worker/tick_worker_support
import glot_core/helpers/dict_helpers
import glot_core/helpers/list_helpers
import glot_core/job/job_model
import pog
import wisp
import youid/uuid.{type Uuid}

pub type Message {
  Tick
  AttemptCompleted(pid: process.Pid, log_entry: core.JobLogEntry)
  AttemptTimedOut(pid: process.Pid)
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
    tick_timer: Option(process.Timer),
    core: core.State,
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
        tick_timer: option.None,
        core: core.new(),
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
    Tick -> {
      let mode = server_mode.get_mode(state.server_mode_subject)
      case mode {
        // The worker starts before startup migrations finish. Keep polling so
        // it can begin draining jobs once the server switches to Running.
        server_mode.Maintenance -> {
          let #(next_core, commands) = core.on_tick(state.core, mode, option.None)
          actor.continue(run_commands(State(..state, core: next_core), commands))
        }
        server_mode.ShuttingDown -> actor.continue(state)
        server_mode.Running -> {
          let #(next_state, maybe_delay) = run_once(state)
          let #(next_core, commands) =
            core.on_tick(next_state.core, mode, maybe_delay)
          actor.continue(run_commands(State(..next_state, core: next_core), commands))
        }
      }
    }
    AttemptCompleted(pid, log_entry) -> {
      let #(next_core, commands) =
        core.on_attempt_completed(state.core, pid, log_entry)
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
    AttemptTimedOut(pid) -> {
      case core.active_attempt(state.core) {
        option.Some(active) if active.pid == pid -> {
          let timeout_log_entry = prepare_timeout_log_entry(active.ctx, active.job)
          let #(next_core, commands) =
            core.on_attempt_timed_out(state.core, pid, timeout_log_entry)
          actor.continue(run_commands(State(..state, core: next_core), commands))
        }
        _ -> actor.continue(state)
      }
    }
  }
}

fn schedule_tick_after(state: State, delay: Int) -> State {
  let timer =
    tick_worker_support.reschedule(state.tick_timer, state.subject, delay, Tick)
  State(..state, tick_timer: option.Some(timer))
}

fn trigger_tick_now(state: State) -> State {
  tick_worker_support.trigger_now(state.tick_timer, state.subject, Tick)
  State(..state, tick_timer: option.None)
}

fn run_once(state: State) -> #(State, Option(Int)) {
  case core.active_attempt(state.core) {
    option.Some(_) -> #(state, option.None)
    option.None -> {
      let effect_runtime =
        runtime.new(
          state.db,
          state.app_config_cache_subject,
          state.language_version_cache_subject,
        )
      let ctx = context_from_state(state, option.None, option.None)

      let #(periodic_result, _) =
        periodic_job_manager_domain.enqueue_next_due_periodic_job(ctx)
        |> interpreter.run(effect_runtime, ctx)

      case periodic_result {
        Ok(True) -> #(state, option.Some(0))
        Ok(False) -> recover_or_claim_job(state, effect_runtime, ctx)
        Error(err) -> {
          wisp.log_error(
            "Failed to enqueue periodic job: " <> string.inspect(err),
          )
          recover_or_claim_job(state, effect_runtime, ctx)
        }
      }
    }
  }
}

fn recover_or_claim_job(
  state: State,
  effect_runtime: runtime.Runtime,
  ctx: context.Context,
) -> #(State, Option(Int)) {
  let #(recovery_result, _) =
    job_manager_domain.recover_next_expired_job(ctx)
    |> interpreter.run(effect_runtime, ctx)

  case recovery_result {
    Ok(option.Some(recovered_job)) -> {
      insert_job_log(
        state.db,
        prepare_recovered_timeout_log_entry(ctx, recovered_job),
      )
      #(state, option.Some(0))
    }
    Ok(option.None) -> claim_and_process_job(state, effect_runtime, ctx)
    Error(err) -> {
      wisp.log_error("Failed to recover expired job: " <> string.inspect(err))
      claim_and_process_job(state, effect_runtime, ctx)
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
        option.None -> #(state, option.Some(core.idle_poll_ms))
      }
    Error(err) -> {
      wisp.log_error("Failed to claim job: " <> string.inspect(err))
      #(state, option.Some(core.idle_poll_ms))
    }
  }
}

fn start_attempt(state: State, job: job_model.Job) -> State {
  let ctx =
    context_from_state(state, job.request_id, option.Some(job.timeout_seconds))
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

  let #(next_core, commands) =
    core.on_attempt_started(state.core, pid, timeout_timer, job, ctx)
  run_commands(State(..state, core: next_core), commands)
}

fn prepare_timeout_log_entry(
  ctx: context.Context,
  job: job_model.Job,
) -> core.JobLogEntry {
  core.JobLogEntry(
    ..prepare_log_entry(
      ctx,
      program_state.new_state(),
      job,
      Error(error.infra(infra_error.JobTimeoutExceeded)),
    ),
    created_at: basic_handlers.system_time(),
  )
}

fn prepare_recovered_timeout_log_entry(
  ctx: context.Context,
  job: job_model.Job,
) -> core.JobLogEntry {
  core.JobLogEntry(
    ..prepare_timeout_log_entry(ctx, job),
    created_at: ctx.timestamp,
  )
}

fn prepare_log_entry(
  ctx: context.Context,
  state: program_state.State,
  job: job_model.Job,
  result: Result(Nil, error.Error),
) -> core.JobLogEntry {
  let id = basic_handlers.uuid_v7(ctx.timestamp)
  let duration_ns = erlang.perf_counter_ns() - ctx.started_at

  let error = case result {
    Ok(_) -> option.None
    Error(err) -> option.Some(err)
  }

  core.JobLogEntry(
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
  timeout_seconds: option.Option(Int),
) -> context.Context {
  let now = basic_handlers.system_time()
  let started_at = erlang.perf_counter_ns()

  context.Context(
    config: state.config,
    regexes: state.regexes,
    request_id: request_id
      |> option.lazy_unwrap(fn() { basic_handlers.uuid_v7(now) }),
    started_at: started_at,
    deadline_at_monotonic_ns: option.map(timeout_seconds, fn(seconds) {
      started_at + { seconds * 1_000_000_000 }
    }),
    timestamp: now,
    client_info: context.empty_client_info(),
  )
}

fn insert_job_log(db: pog.Connection, entry: core.JobLogEntry) -> Nil {
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
  let res =
    db_helpers.execute(db_helpers.new(db), query, fn(err) {
      string.inspect(err)
    })

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

fn run_commands(state: State, commands: List(core.Command)) -> State {
  list.fold(commands, state, fn(state: State, command) {
    case command {
      core.ScheduleTick(delay_ms) -> schedule_tick_after(state, delay_ms)
      core.TriggerTickNow -> trigger_tick_now(state)
      core.JobStarted -> {
        job_tracker.job_started(state.job_tracker_subject)
        state
      }
      core.JobFinished -> {
        job_tracker.job_finished(state.job_tracker_subject)
        state
      }
      core.CancelTimer(timer) -> {
        let _ = process.cancel_timer(timer)
        state
      }
      core.KillAttempt(pid) -> {
        process.kill(pid)
        state
      }
      core.TimeoutJob(ctx, job) -> {
        let effect_runtime =
          runtime.new(
            state.db,
            state.app_config_cache_subject,
            state.language_version_cache_subject,
          )
        let #(result, _) =
          job_manager_domain.timeout_job(ctx, job)
          |> interpreter.run(effect_runtime, ctx)

        case result {
          Ok(_) -> state
          Error(err) -> {
            wisp.log_error("Failed to time out job: " <> string.inspect(err))
            state
          }
        }
      }
      core.InsertJobLog(entry) -> {
        insert_job_log(state.db, entry)
        state
      }
    }
  })
}
