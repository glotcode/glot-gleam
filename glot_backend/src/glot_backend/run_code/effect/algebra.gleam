import gleam/option.{type Option}
import glot_backend/run_code/model/config.{type DockerRunConfig}
import glot_backend/system/effect/error/run_request_error
import glot_core/language.{type Language}
import glot_core/run

pub type RunCodeEffect(next) {
  RunCode(
    Option(DockerRunConfig),
    run.RunRequest,
    fn(Result(run.RunResult, run_request_error.RunRequestError)) -> next,
  )
  GetLanguageVersion(
    Option(DockerRunConfig),
    Language,
    fn(Result(run.RunResult, run_request_error.RunRequestError)) -> next,
  )
}

pub fn map(effect: RunCodeEffect(a), f: fn(a) -> b) -> RunCodeEffect(b) {
  case effect {
    RunCode(config, request, next) ->
      RunCode(config, request, fn(value) { f(next(value)) })
    GetLanguageVersion(config, language, next) ->
      GetLanguageVersion(config, language, fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  RunCodeEffectName
  GetLanguageVersionEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    RunCodeEffectName -> "run_code"
    GetLanguageVersionEffectName -> "get_language_version"
  }
}
