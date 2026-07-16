import gleam/option.{type Option}
import glot_backend/dynamic_config.{type DockerRunConfig}
import glot_backend/effect/error/run_request_error
import glot_core/run

pub type DockerRunEffect(next) {
  RunCode(
    Option(DockerRunConfig),
    run.RunRequest,
    fn(Result(run.RunResult, run_request_error.RunRequestError)) -> next,
  )
}

pub fn map(effect: DockerRunEffect(a), f: fn(a) -> b) -> DockerRunEffect(b) {
  case effect {
    RunCode(config, request, next) ->
      RunCode(config, request, fn(value) { f(next(value)) })
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
