import gleam/option
import glot_backend/context
import glot_backend/effect/docker_run/docker_run_handlers
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
  cfg: context.Config,
  lang: language.Language,
) -> Result(run.RunResult, error.RunRequestError) {
  let run_request =
    run.RunRequest(
      image: language.container_image(lang),
      payload: run.RunRequestPayload(
        run_instructions: language.version_run_instructions(lang),
        files: [],
        stdin: option.None,
      ),
    )

  docker_run_handlers.run_code(cfg, run_request)
}
