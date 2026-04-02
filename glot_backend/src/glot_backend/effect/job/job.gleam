import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/job as job_type
import youid/uuid.{type Uuid}

pub type JobEffect(next) {
  GetNextJob(
    now: Timestamp,
    pending_status: job_type.Status,
    running_status: job_type.Status,
    next: fn(option.Option(job_type.Job)) -> next,
  )
  InsertJob(
    job_type.Job,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  MarkJobDone(
    id: Uuid,
    completed_at: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  RescheduleJob(
    id: Uuid,
    run_at: Timestamp,
    last_error: option.Option(String),
    updated_at: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: JobEffect(a), f: fn(a) -> b) -> JobEffect(b) {
  case effect {
    GetNextJob(now:, pending_status:, running_status:, next:) ->
      GetNextJob(
        now: now,
        pending_status: pending_status,
        running_status: running_status,
        next: fn(value) { f(next(value)) },
      )
    InsertJob(job, next) -> InsertJob(job, next: fn(value) { f(next(value)) })
    MarkJobDone(id, completed_at, next) ->
      MarkJobDone(id, completed_at, next: fn(value) { f(next(value)) })
    RescheduleJob(id, run_at, last_error, updated_at, next) ->
      RescheduleJob(id, run_at, last_error, updated_at, next: fn(value) {
        f(next(value))
      })
  }
}

pub type EffectName {
  GetNextJobEffectName
  InsertJobEffectName
  MarkJobDoneEffectName
  RescheduleJobEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetNextJobEffectName -> "get_next_job"
    InsertJobEffectName -> "insert_job"
    MarkJobDoneEffectName -> "mark_job_done"
    RescheduleJobEffectName -> "reschedule_job"
  }
}
