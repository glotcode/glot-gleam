import gleam/dynamic
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/run_code/effect/effect as get_language_version_effect
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/hydrated_context as request_context
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
