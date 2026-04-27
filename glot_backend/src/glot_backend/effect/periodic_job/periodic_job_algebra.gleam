import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_core/periodic_job/periodic_job_model

pub type PeriodicJobEffect(next) {
  GetNextPeriodicJob(
    now: Timestamp,
    next: fn(Option(periodic_job_model.PeriodicJob)) -> next,
  )
  CreatePeriodicJob(
    periodic_job_model.PeriodicJob,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdatePeriodicJob(
    periodic_job_model.PeriodicJob,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(
  effect: PeriodicJobEffect(a),
  f: fn(a) -> b,
) -> PeriodicJobEffect(b) {
  case effect {
    GetNextPeriodicJob(now:, next:) ->
      GetNextPeriodicJob(now: now, next: fn(value) { f(next(value)) })
    CreatePeriodicJob(periodic_job, next) ->
      CreatePeriodicJob(periodic_job, next: fn(value) { f(next(value)) })
    UpdatePeriodicJob(periodic_job, next) ->
      UpdatePeriodicJob(periodic_job, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetNextPeriodicJobEffectName
  CreatePeriodicJobEffectName
  UpdatePeriodicJobEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetNextPeriodicJobEffectName -> "get_next_periodic_job"
    CreatePeriodicJobEffectName -> "create_periodic_job"
    UpdatePeriodicJobEffectName -> "update_periodic_job"
  }
}
