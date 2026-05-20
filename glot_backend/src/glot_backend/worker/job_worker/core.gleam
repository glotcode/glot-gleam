import gleam/erlang/process
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/log
import glot_backend/server_mode
import glot_core/job/job_model
import youid/uuid.{type Uuid}

pub const idle_poll_ms = 1000

pub type ActiveAttempt {
  ActiveAttempt(
    pid: process.Pid,
    timer: process.Timer,
    job: job_model.Job,
    ctx: context.Context,
  )
}

pub type State {
  State(active_attempt: option.Option(ActiveAttempt))
}

pub type JobLogEntry {
  JobLogEntry(
    id: Uuid,
    request_id: option.Option(Uuid),
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

pub type Command {
  ScheduleTick(delay_ms: Int)
  TriggerTickNow
  JobStarted
  JobFinished
  CancelTimer(timer: process.Timer)
  KillAttempt(pid: process.Pid)
  TimeoutJob(ctx: context.Context, job: job_model.Job)
  InsertJobLog(entry: JobLogEntry)
}

pub fn new() -> State {
  State(active_attempt: option.None)
}

pub fn active_attempt(state: State) -> option.Option(ActiveAttempt) {
  state.active_attempt
}

pub fn on_tick(
  state: State,
  mode: server_mode.Mode,
  maybe_delay: option.Option(Int),
) -> #(State, List(Command)) {
  case mode {
    server_mode.Maintenance -> #(state, [ScheduleTick(idle_poll_ms)])
    server_mode.ShuttingDown -> #(state, [])
    server_mode.Running ->
      case maybe_delay {
        option.Some(delay) if delay <= 0 -> #(state, [TriggerTickNow])
        option.Some(delay) -> #(state, [ScheduleTick(delay)])
        option.None -> #(state, [])
      }
  }
}

pub fn on_attempt_started(
  _state: State,
  pid: process.Pid,
  timer: process.Timer,
  job: job_model.Job,
  ctx: context.Context,
) -> #(State, List(Command)) {
  #(State(active_attempt: option.Some(ActiveAttempt(pid, timer, job, ctx))), [
    JobStarted,
  ])
}

pub fn on_attempt_completed(
  state: State,
  pid: process.Pid,
  log_entry: JobLogEntry,
) -> #(State, List(Command)) {
  case state.active_attempt {
    option.Some(active) if active.pid == pid -> #(
      State(active_attempt: option.None),
      [
        CancelTimer(active.timer),
        JobFinished,
        InsertJobLog(log_entry),
        TriggerTickNow,
      ],
    )
    _ -> #(state, [])
  }
}

pub fn on_attempt_timed_out(
  state: State,
  pid: process.Pid,
  timeout_log_entry: JobLogEntry,
) -> #(State, List(Command)) {
  case state.active_attempt {
    option.Some(active) if active.pid == pid -> #(
      State(active_attempt: option.None),
      [
        KillAttempt(active.pid),
        TimeoutJob(active.ctx, active.job),
        JobFinished,
        InsertJobLog(timeout_log_entry),
        TriggerTickNow,
      ],
    )
    _ -> #(state, [])
  }
}
