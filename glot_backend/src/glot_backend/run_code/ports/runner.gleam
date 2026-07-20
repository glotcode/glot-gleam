import glot_backend/run_code/model/config.{type DockerRunConfig}
import glot_backend/system/effect/error/run_request_error
import glot_core/run.{type RunRequest, type RunResult}

pub type Runner {
  Runner(
    run: fn(DockerRunConfig, RunRequest, Int) ->
      Result(RunResult, run_request_error.RunRequestError),
  )
}
