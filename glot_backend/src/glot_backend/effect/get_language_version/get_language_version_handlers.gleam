import glot_backend/context
import glot_backend/effect/error
import glot_core/language
import glot_core/run

pub type GetLanguageVersionHandlers {
  GetLanguageVersionHandlers(
    get_language_version: fn(context.Config, language.Language) ->
      Result(run.RunResult, error.RunRequestError),
  )
}

pub fn new() -> GetLanguageVersionHandlers {
  GetLanguageVersionHandlers(get_language_version: get_language_version)
}

pub fn get_language_version(
  _cfg: context.Config,
  _lang: language.Language,
) -> Result(run.RunResult, error.RunRequestError) {
  Error(error.InternalRunRequestError(
    "get_language_version handler requires app_config-backed runtime",
  ))
}
