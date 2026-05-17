import glot_backend/context
import glot_backend/effect/error/run_request_error
import glot_core/language
import glot_core/run
import wisp

pub type GetLanguageVersionHandlers {
  GetLanguageVersionHandlers(
    get_language_version: fn(context.Config, language.Language) ->
      Result(run.RunResult, run_request_error.RunRequestError),
  )
}

pub fn new() -> GetLanguageVersionHandlers {
  GetLanguageVersionHandlers(get_language_version: get_language_version)
}

pub fn get_language_version(
  _cfg: context.Config,
  _lang: language.Language,
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  wisp.log_error(
    "get_language_version handler requires app_config-backed runtime",
  )
  Error(run_request_error.ServerRunRequestError)
}
