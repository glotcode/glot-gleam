import glot_backend/context
import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_core/run

pub fn attempt_post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> effect_model.Program(Result(run.RunResult, error.RunRequestError)) {
  effect_model.Impure(
    effect_model.DockerRunEffect(
      docker_run.AttemptPostRunRequest(cfg, request, effect_model.Pure),
    ),
  )
}

pub fn post_run_request(
  cfg: context.Config,
  request: run.RunRequest,
) -> effect_model.Program(run.RunResult) {
  effect_model.Impure(
    effect_model.DockerRunEffect(
      docker_run.AttemptPostRunRequest(cfg, request, fn(run_result) {
        case run_result {
          Ok(value) -> effect_model.Pure(value)
          Error(err) -> effect_model.Fail(error.RunError(err))
        }
      }),
    ),
  )
}
