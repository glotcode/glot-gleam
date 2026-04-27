import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error

pub type JobLogEffect(next) {
  DeleteJobLogBefore(
    before: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: JobLogEffect(a), f: fn(a) -> b) -> JobLogEffect(b) {
  case effect {
    DeleteJobLogBefore(before:, next:) ->
      DeleteJobLogBefore(before: before, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  DeleteJobLogBeforeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    DeleteJobLogBeforeEffectName -> "delete_job_log_before"
  }
}
