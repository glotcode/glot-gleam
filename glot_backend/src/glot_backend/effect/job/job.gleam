import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/job as job_type

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
  UpdateJob(
    job_type.Job,
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
    UpdateJob(job, next) -> UpdateJob(job, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetNextJobEffectName
  InsertJobEffectName
  UpdateJobEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetNextJobEffectName -> "get_next_job"
    InsertJobEffectName -> "insert_job"
    UpdateJobEffectName -> "update_job"
  }
}
