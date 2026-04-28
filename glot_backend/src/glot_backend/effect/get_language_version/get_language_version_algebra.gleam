import glot_backend/context
import glot_backend/effect/error
import glot_core/language.{type Language}
import glot_core/run

pub type GetLanguageVersionEffect(next) {
  GetLanguageVersion(
    context.Config,
    Language,
    fn(Result(run.RunResult, error.RunRequestError)) -> next,
  )
}

pub fn map(
  effect: GetLanguageVersionEffect(a),
  f: fn(a) -> b,
) -> GetLanguageVersionEffect(b) {
  case effect {
    GetLanguageVersion(cfg, language, next) ->
      GetLanguageVersion(cfg, language, fn(value) { f(next(value)) })
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
