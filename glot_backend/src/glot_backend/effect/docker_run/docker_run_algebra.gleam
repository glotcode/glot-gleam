import glot_backend/effect/error
import glot_core/run

pub type DockerRunEffect(next) {
  RunCode(
    run.RunRequest,
    fn(Result(run.RunResult, error.RunRequestError)) -> next,
  )
}

pub fn map(effect: DockerRunEffect(a), f: fn(a) -> b) -> DockerRunEffect(b) {
  case effect {
    RunCode(request, next) ->
      RunCode(request, fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  RunCodeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    RunCodeEffectName -> "run_code"
  }
}
