import glot_backend/context
import glot_backend/effect/error
import glot_core/run

pub type DockerRunHandlers {
  DockerRunHandlers(
    post_run_request: fn(context.Config, run.RunRequest) ->
      Result(run.RunResult, error.RunRequestError),
  )
}
