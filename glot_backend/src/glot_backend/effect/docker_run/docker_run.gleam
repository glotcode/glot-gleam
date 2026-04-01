import glot_backend/context
import glot_backend/effect/error
import glot_core/run

pub type DockerRunEffect(next) {
  AttemptPostRunRequest(
    context.Config,
    run.RunRequest,
    fn(Result(run.RunResult, error.RunRequestError)) -> next,
  )
}

pub fn map(effect: DockerRunEffect(a), f: fn(a) -> b) -> DockerRunEffect(b) {
  case effect {
    AttemptPostRunRequest(cfg, request, next) ->
      AttemptPostRunRequest(cfg, request, fn(value) { f(next(value)) })
  }
}
