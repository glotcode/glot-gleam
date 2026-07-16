import gleam/dynamic
import glot_backend/dynamic_config
import glot_backend/effect/get_language_version/get_language_version_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/request_context
import glot_core/run

pub fn get_language_version(
  request_ctx: request_context.RequestContext,
  request: run.GetLanguageVersionRequest,
) -> program_types.Program(run.RunResult) {
  let config = request_ctx.dynamic_config

  get_language_version_effect.get_language_version(
    dynamic_config.docker_run_config(config),
    request.language,
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(run.GetLanguageVersionRequest) {
  program.decode_dynamic(data, run.get_language_version_request_decoder())
}
