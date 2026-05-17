import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error/db_error

pub type ApiLogEffect(next) {
  DeleteApiLogBefore(
    before: Timestamp,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub fn map(effect: ApiLogEffect(a), f: fn(a) -> b) -> ApiLogEffect(b) {
  case effect {
    DeleteApiLogBefore(before:, next:) ->
      DeleteApiLogBefore(before: before, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  DeleteApiLogBeforeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    DeleteApiLogBeforeEffectName -> "delete_api_log_before"
  }
}
