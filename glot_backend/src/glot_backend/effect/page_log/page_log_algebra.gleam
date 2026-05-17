import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error/db_error

pub type PageLogEffect(next) {
  DeletePageLogBefore(
    before: Timestamp,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub fn map(effect: PageLogEffect(a), f: fn(a) -> b) -> PageLogEffect(b) {
  case effect {
    DeletePageLogBefore(before:, next:) ->
      DeletePageLogBefore(before: before, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  DeletePageLogBeforeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    DeletePageLogBeforeEffectName -> "delete_page_log_before"
  }
}
