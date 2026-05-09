import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_core/run

pub fn run_code(request: run.RunRequest) -> program_types.Program(run.RunResult) {
  program_types.Impure(
    program_types.DockerRunEffect(
      docker_run_algebra.RunCode(request, fn(run_result) {
        case run_result {
          Ok(value) -> program_types.Pure(value)
          Error(err) -> program_types.Fail(error.RunError(err))
        }
      }),
    ),
  )
}
