import gleam/option.{type Option}
import glot_backend/dynamic_config.{type DockerRunConfig}
import glot_backend/effect/error/run_request_error
import glot_core/language.{type Language}
import glot_core/run

pub type GetLanguageVersionEffect(next) {
  GetLanguageVersion(
    Option(DockerRunConfig),
    Language,
    fn(Result(run.RunResult, run_request_error.RunRequestError)) -> next,
  )
}

pub fn map(
  effect: GetLanguageVersionEffect(a),
  f: fn(a) -> b,
) -> GetLanguageVersionEffect(b) {
  case effect {
    GetLanguageVersion(docker_run_config, language, next) ->
      GetLanguageVersion(docker_run_config, language, fn(value) {
        f(next(value))
      })
  }
}

pub type EffectName {
  GetLanguageVersionEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetLanguageVersionEffectName -> "get_language_version"
  }
}
