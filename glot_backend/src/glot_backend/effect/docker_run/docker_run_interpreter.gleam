import gleam/option
import gleam/result
import glot_backend/dynamic_config
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/worker/app_config_cache_worker

pub fn run(
  effect: docker_run_algebra.DockerRunEffect(program_types.Program(a)),
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    docker_run_algebra.RunCode(request, next) -> {
      let started_at = erlang.perf_counter_ns()
      let run_result =
        load_config(runtime)
        |> result.try(fn(config) {
          case dynamic_config.docker_run_config(config) {
            option.Some(docker_run) ->
              runtime.handlers.docker_run.run_code(docker_run, request)
            option.None ->
              Error(error.InternalRunRequestError(
                "Missing docker_run app_config",
              ))
          }
        })
      continue(
        next(run_result),
        program_state.add_effect_measurement(
          state,
          effect_trace.DockerRunEffectName(docker_run_algebra.RunCodeEffectName),
          effect_trace.DockerRunEffectCategory,
          started_at,
        ),
      )
    }
  }
}

fn load_config(
  runtime: runtime.Runtime,
) -> Result(dynamic_config.DynamicConfig, error.RunRequestError) {
  case runtime.app_config_cache_subject {
    option.Some(subject) ->
      app_config_cache_worker.get_config(subject)
      |> result.map_error(map_query_error)
    option.None ->
      runtime.handlers.app_config.list_entries()
      |> result.map_error(map_query_error)
      |> result.try(fn(entries) {
        dynamic_config.from_entries(entries)
        |> result.map_error(fn(message) {
          error.InternalRunRequestError(message)
        })
      })
  }
}

fn map_query_error(err: error.DbQueryError) -> error.RunRequestError {
  let error.DbQueryError(message: message) = err
  error.InternalRunRequestError(message)
}
