import glot_backend/effect/error
import glot_core/run_log_model.{type RunLog}

pub type RunLogEffect(next) {
  CreateRunLog(
    run_log: RunLog,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(
  effect: RunLogEffect(a),
  f: fn(a) -> b,
) -> RunLogEffect(b) {
  case effect {
    CreateRunLog(run_log:, next:) ->
      CreateRunLog(
        run_log: run_log,
        next: fn(value) { f(next(value)) },
      )
  }
}

pub type EffectName {
  CreateRunLogEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    CreateRunLogEffectName -> "create_run_log"
  }
}
