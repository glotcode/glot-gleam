import glot_backend/effect/docker_run/docker_run
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: docker_run.DockerRunEffect(effect_model.Program(a)),
  handlers: handlers_types.Handlers,
  state: program_state.State,
  continue: fn(effect_model.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    docker_run.AttemptPostRunRequest(cfg, request, next) -> {
      let started_at = erlang.perf_counter_ns()
      let run_result = handlers.docker_run.post_run_request(cfg, request)
      continue(
        next(run_result),
        program_state.add_effect_measurement(
          state,
          effect_model.DockerRunEffectName(
            docker_run.AttemptPostRunRequestEffectName,
          ),
          effect_model.DockerRunEffectCategory,
          started_at,
        ),
      )
    }
  }
}
