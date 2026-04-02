import glot_backend/context
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/program_types
import glot_backend/effect/error
import glot_core/run

pub fn attempt_post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> program_types.Program(Result(run.RunResult, error.RunRequestError)) {
  program_types.Impure(
    program_types.DockerRunEffect(
      docker_run.AttemptPostRunRequest(cfg, request, program_types.Pure),
    ),
  )
}

pub fn post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> program_types.Program(run.RunResult) {
  program_types.Impure(
    program_types.DockerRunEffect(
      docker_run.AttemptPostRunRequest(cfg, request, fn(run_result) {
        case run_result {
          Ok(value) -> program_types.Pure(value)
          Error(err) -> program_types.Fail(error.RunError(err))
        }
      }),
    ),
  )
}
