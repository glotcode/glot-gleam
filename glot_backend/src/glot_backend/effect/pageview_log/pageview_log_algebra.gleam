import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error

pub type PageviewLogEffect(next) {
  DeletePageviewLogBefore(
    before: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(
  effect: PageviewLogEffect(a),
  f: fn(a) -> b,
) -> PageviewLogEffect(b) {
  case effect {
    DeletePageviewLogBefore(before:, next:) ->
      DeletePageviewLogBefore(
        before: before,
        next: fn(value) { f(next(value)) },
      )
  }
}

pub type EffectName {
  DeletePageviewLogBeforeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    DeletePageviewLogBeforeEffectName -> "delete_pageview_log_before"
  }
}
