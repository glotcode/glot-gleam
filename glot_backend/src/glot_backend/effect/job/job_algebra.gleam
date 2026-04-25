import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_core/job/job_model
import youid/uuid.{type Uuid}

pub type JobEffect(next) {
  GetNextJob(
    now: Timestamp,
    pending_status: job_model.Status,
    next: fn(Option(job_model.Job)) -> next,
  )
  GetJobById(
    id: Uuid,
    next: fn(Option(job_model.Job)) -> next,
  )
  CreateJob(
    job_model.Job,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdateJob(
    job_model.Job,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  DeleteJob(
    id: Uuid,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: JobEffect(a), f: fn(a) -> b) -> JobEffect(b) {
  case effect {
    GetNextJob(now:, pending_status:, next:) ->
      GetNextJob(
        now: now,
        pending_status: pending_status,
        next: fn(value) { f(next(value)) },
      )
    GetJobById(id:, next:) ->
      GetJobById(id: id, next: fn(value) { f(next(value)) })
    CreateJob(job, next) -> CreateJob(job, next: fn(value) { f(next(value)) })
    UpdateJob(job, next) -> UpdateJob(job, next: fn(value) { f(next(value)) })
    DeleteJob(id, next) -> DeleteJob(id, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetNextJobEffectName
  GetJobByIdEffectName
  CreateJobEffectName
  UpdateJobEffectName
  DeleteJobEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetNextJobEffectName -> "get_next_job"
    GetJobByIdEffectName -> "get_job_by_id"
    CreateJobEffectName -> "create_job"
    UpdateJobEffectName -> "update_job"
    DeleteJobEffectName -> "delete_job"
  }
}
