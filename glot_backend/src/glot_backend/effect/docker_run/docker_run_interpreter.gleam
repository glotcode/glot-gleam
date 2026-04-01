import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/types
import glot_backend/erlang

pub fn run(
  effect: docker_run.DockerRunEffect(types.Program(a)),
  handlers: runtime_types.Handlers,
  state: types.State,
  continue: fn(types.Program(a), types.State) -> #(Result(a, error.Error), types.State),
  measure: fn(types.State, types.EffectName, Int) -> types.State,
) -> #(Result(a, error.Error), types.State) {
  case effect {
    docker_run.AttemptPostRunRequest(cfg, request, next) -> {
      let started_at = erlang.perf_counter_ns()
      let run_result = handlers.post_run_request(cfg, request)
      continue(
        next(run_result),
        measure(state, types.DockerRunRequestEffect, started_at),
      )
    }
  }
}
