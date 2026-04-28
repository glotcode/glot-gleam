import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/effect/docker_run/docker_run_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/language
import glot_core/run

pub fn get_language_version(
  ctx: context.Context,
  request: run.GetLanguageVersionRequest,
) -> program_types.Program(run.RunResult) {
  let run_request =
    run.RunRequest(
      image: language.container_image(request.language),
      payload: run.RunRequestPayload(
        run_instructions: language.version_run_instructions(request.language),
        files: [],
        stdin: option.None,
      ),
    )

  docker_run_effect.run_code(ctx.config, run_request)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(run.GetLanguageVersionRequest) {
  program.decode_dynamic(data, run.get_language_version_request_decoder())
}
