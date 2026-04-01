import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/erlang

pub fn run(
  effect: docker_run.DockerRunEffect(effect_model.Program(a)),
  handlers: handlers_types.Handlers,
  state: effect_model.State,
  continue: fn(effect_model.Program(a), effect_model.State) ->
    #(Result(a, error.Error), effect_model.State),
  measure: fn(effect_model.State, effect_model.EffectName, Int) ->
    effect_model.State,
) -> #(Result(a, error.Error), effect_model.State) {
  case effect {
    docker_run.AttemptPostRunRequest(cfg, request, next) -> {
      let started_at = erlang.perf_counter_ns()
      let run_result = handlers.docker_run.post_run_request(cfg, request)
      continue(
        next(run_result),
        measure(state, effect_model.DockerRunRequestEffect, started_at),
      )
    }
  }
}
