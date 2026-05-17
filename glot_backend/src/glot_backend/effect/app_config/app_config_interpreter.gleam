import gleam/json
import gleam/option
import gleam/result
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/error/db_error
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/erlang
import glot_backend/worker/app_config_cache_worker
import glot_core/availability_mode
import glot_core/public_action

pub fn run(
  effect: app_config_algebra.AppConfigEffect(program_types.Program(a)),
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(b, program_state.State),
) -> #(b, program_state.State) {
  case effect {
    app_config_algebra.GetDynamicConfig(next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = case runtime.app_config_cache_subject {
        option.Some(subject) -> app_config_cache_worker.get_config(subject)
        option.None ->
          runtime.handlers.app_config.list_entries()
          |> result.try(fn(entries) {
            dynamic_config.from_entries(entries)
            |> result.map_error(db_error.DbQueryError)
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
    app_config_algebra.UpsertDebugConfig(config:, updated_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "debug",
          "enabled",
          json.bool(config.enabled) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertDebugConfigEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertAvailabilityConfig(
      config: config,
      updated_at: updated_at,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "availability",
          "mode",
          config.mode |> availability_mode.encode |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "availability",
            "message",
            json.string(config.message) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "availability",
            "retry_after_seconds",
            json.nullable(config.retry_after_seconds, json.int)
              |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertAvailabilityConfigEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertAuthConfig(config:, updated_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "auth",
          "login_token_max_age",
          json.int(config.login_token_max_age) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "auth",
            "session_token_max_age",
            json.int(config.session_token_max_age) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "auth",
            "session_cookie_max_age",
            json.int(config.session_cookie_max_age) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "auth",
            "session_refresh_interval_seconds",
            json.int(config.session_refresh_interval_seconds)
              |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "auth",
            "session_previous_token_grace_seconds",
            json.int(config.session_previous_token_grace_seconds)
              |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "auth",
            "session_heartbeat_interval_seconds",
            json.int(config.session_heartbeat_interval_seconds)
              |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertAuthConfigEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertCleanupConfig(config:, updated_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "cleanup",
          "api_log_retention_days",
          json.int(config.api_log_retention_days) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "cleanup",
            "page_log_retention_days",
            json.int(config.page_log_retention_days) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "cleanup",
            "pageview_log_retention_days",
            json.int(config.pageview_log_retention_days) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "cleanup",
            "run_log_retention_days",
            json.int(config.run_log_retention_days) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "cleanup",
            "job_log_retention_days",
            json.int(config.job_log_retention_days) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "cleanup",
            "jobs_retention_days",
            json.int(config.jobs_retention_days) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "cleanup",
            "login_tokens_retention_days",
            json.int(config.login_tokens_retention_days) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "cleanup",
            "user_actions_retention_days",
            json.int(config.user_actions_retention_days) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertCleanupConfigEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertLogWorkerConfig(config:, updated_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "log_worker",
          "flush_interval_ms",
          json.int(config.flush_interval_ms) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "log_worker",
            "max_batch_size",
            json.int(config.max_batch_size) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "log_worker",
            "max_buffer_size",
            json.int(config.max_buffer_size) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertLogWorkerConfigEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertLanguageVersionCacheWorkerConfig(
      config:,
      updated_at:,
      next:,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "language_version_cache_worker",
          "refresh_interval_ms",
          json.int(config.refresh_interval_ms) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "language_version_cache_worker",
            "refresh_step_delay_ms",
            json.int(config.refresh_step_delay_ms) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "language_version_cache_worker",
            "refresh_step_jitter_ms",
            json.int(config.refresh_step_jitter_ms) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "language_version_cache_worker",
            "default_timeout_ms",
            json.int(config.default_timeout_ms) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertLanguageVersionCacheWorkerConfigEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertRateLimitPolicy(
      action:,
      policy:,
      updated_at:,
      next:,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "rate_limit",
          public_action.to_string(action),
          dynamic_config.encode_rate_limit_policy(policy) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
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
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "docker_run",
            "access_token",
            json.string(config.access_token) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "docker_run",
            "default_timeout_ms",
            json.int(config.default_timeout_ms) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
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
    app_config_algebra.UpsertCloudflareConfig(config:, updated_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "cloudflare",
          "account_id",
          json.string(config.account_id) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "cloudflare",
            "api_token",
            json.string(config.api_token) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertCloudflareConfigEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    app_config_algebra.UpsertEmailConfig(config:, updated_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.app_config.upsert_entry(
          "email",
          "from_address",
          json.string(config.from_address) |> json.to_string(),
          updated_at,
        )
        |> result.map_error(error.database_command_error)
        |> result.try(fn(_) {
          runtime.handlers.app_config.upsert_entry(
            "email",
            "from_name",
            json.nullable(config.from_name, json.string) |> json.to_string(),
            updated_at,
          )
          |> result.map_error(error.database_command_error)
        })
        |> result.try(fn(_) { refresh_dynamic_config(runtime) })

      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AppConfigEffectName(
            app_config_algebra.UpsertEmailConfigEffectName,
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
      |> result.map_error(error.database_query_error)
    option.None ->
      runtime.handlers.app_config.list_entries()
      |> result.map_error(error.database_query_error)
      |> result.try(fn(entries) {
        dynamic_config.from_entries(entries)
        |> result.map_error(fn(message) {
          error.database_query_error(db_error.DbQueryError(message))
        })
      })
  }
}
