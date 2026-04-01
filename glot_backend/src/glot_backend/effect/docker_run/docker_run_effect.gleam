import glot_backend/context
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/error
import glot_backend/effect/types
import glot_core/run

pub fn attempt_post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> types.Program(Result(run.RunResult, error.RunRequestError)) {
  types.Impure(
    types.DockerRunEffect(
      docker_run.AttemptPostRunRequest(cfg, request, types.Pure),
    ),
  )
}

pub fn post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> types.Program(run.RunResult) {
  types.Impure(
    types.DockerRunEffect(
      docker_run.AttemptPostRunRequest(cfg, request, fn(run_result) {
        case run_result {
          Ok(value) -> types.Pure(value)
          Error(err) -> types.Fail(error.RunError(err))
        }
      }),
    ),
  )
}
