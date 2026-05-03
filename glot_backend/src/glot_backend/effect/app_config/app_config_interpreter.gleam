import gleam/json
import gleam/option
import gleam/result
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/worker/app_config_cache_worker
import glot_core/api_action

pub fn run(
  effect: app_config_algebra.AppConfigEffect(program_types.Program(a)),
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) -> #(b, program_state.State),
) -> #(b, program_state.State) {
  case effect {
    app_config_algebra.GetDynamicConfig(next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        case runtime.app_config_cache_subject {
          option.Some(subject) -> app_config_cache_worker.get_config(subject)
          option.None ->
            runtime.handlers.app_config.list_entries()
            |> result.try(fn(entries) {
              dynamic_config.from_entries(entries)
              |> result.map_error(error.DbQueryError)
            })
        }

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.GetDynamicConfigEffectName,
          ),
          effect_trace.DbReadEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertRateLimitPolicy(action:, policy:, updated_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "rate_limit",
          api_action.to_string(action),
          dynamic_config.encode_rate_limit_policy(policy) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.CommandError)
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertRateLimitPolicyEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertDockerRunConfig(config:, updated_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "docker_run",
          "base_url",
          json.string(config.base_url) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.CommandError)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "docker_run",
            "access_token",
            json.string(config.access_token) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.CommandError)
        })
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertDockerRunConfigEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}

fn refresh_dynamic_config(
  runtime: runtime.Runtime,
) -> Result(dynamic_config.DynamicConfig, error.Error) {
  case runtime.app_config_cache_subject {
    option.Some(subject) ->
      app_config_cache_worker.refresh(subject)
      |> result.map_error(error.QueryError)
    option.None ->
      runtime.handlers.app_config.list_entries()
      |> result.map_error(error.QueryError)
      |> result.try(fn(entries) {
        dynamic_config.from_entries(entries)
        |> result.map_error(fn(message) {
          error.QueryError(error.DbQueryError(message))
        })
      })
  }
}
