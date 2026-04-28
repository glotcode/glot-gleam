import gleam/dynamic
import glot_backend/context
import glot_backend/effect/get_language_version/get_language_version_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/run

pub fn get_language_version(
  ctx: context.Context,
  request: run.GetLanguageVersionRequest,
) -> program_types.Program(run.RunResult) {
  get_language_version_effect.get_language_version(ctx.config, request.language)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(run.GetLanguageVersionRequest) {
  program.decode_dynamic(data, run.get_language_version_request_decoder())
}
