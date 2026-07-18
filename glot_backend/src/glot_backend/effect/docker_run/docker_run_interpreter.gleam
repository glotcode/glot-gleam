import gleam/option
import glot_backend/context
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/error/run_request_error
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import wisp

pub fn run(
  effect: docker_run_algebra.DockerRunEffect(program_types.Program(a)),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    docker_run_algebra.RunCode(config, request, next) -> {
      let started_at = erlang.perf_counter_ns()
      let run_result = case config {
        option.Some(docker_run) ->
          runtime.handlers.docker_run.run_code(
            docker_run,
            request,
            option.unwrap(
              context.remaining_timeout_ms(ctx),
              docker_run.default_timeout_ms,
            ),
          )
        option.None -> {
          wisp.log_error("Missing docker_run app_config")
          Error(run_request_error.ServerRunRequestError)
        }
      }
      continue(
        next(run_result),
        program_state.add_effect_measurement(
          state,
          effect_trace.DockerRunEffectName(docker_run_algebra.RunCodeEffectName),
          effect_trace.DockerCallEffect,
          started_at,
        ),
      )
    }
  }
}
