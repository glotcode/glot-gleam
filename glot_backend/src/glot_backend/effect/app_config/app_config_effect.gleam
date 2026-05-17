import gleam/time/timestamp.{type Timestamp}
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/error
import glot_backend/effect/error/db_error
import glot_backend/effect/program_types
import glot_core/public_action.{type PublicAction}

pub fn get_dynamic_config_result() -> program_types.Program(
  Result(dynamic_config.DynamicConfig, db_error.DbQueryError),
) {
  program_types.Impure(
    program_types.AppConfigEffect(app_config_algebra.GetDynamicConfig(
      next: program_types.Pure,
    )),
  )
}

pub fn get_dynamic_config() -> program_types.Program(
  dynamic_config.DynamicConfig,
) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.GetDynamicConfig(next: fn(result) {
        case result {
          Ok(config) -> program_types.Pure(config)
          Error(err) -> program_types.Fail(error.database_query_error(err))
        }
      }),
    ),
  )
}

pub fn upsert_debug_config(
  config: dynamic_config.DebugConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertDebugConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_availability_config(
  config: dynamic_config.AvailabilityConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertAvailabilityConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_auth_config(
  config: dynamic_config.AuthConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertAuthConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_cleanup_config(
  config: dynamic_config.CleanupConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertCleanupConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_log_worker_config(
  config: dynamic_config.LogWorkerConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertLogWorkerConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_language_version_cache_worker_config(
  config: dynamic_config.LanguageVersionCacheWorkerConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertLanguageVersionCacheWorkerConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_rate_limit_policy(
  action: PublicAction,
  policy: dynamic_config.RateLimitPolicy,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertRateLimitPolicy(
        action: action,
        policy: policy,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_docker_run_config(
  config: dynamic_config.DockerRunConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertDockerRunConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_cloudflare_config(
  config: dynamic_config.CloudflareConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertCloudflareConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}

pub fn upsert_email_config(
  config: dynamic_config.EmailConfig,
  updated_at: Timestamp,
) -> program_types.Program(dynamic_config.DynamicConfig) {
  program_types.Impure(
    program_types.AppConfigEffect(
      app_config_algebra.UpsertEmailConfig(
        config: config,
        updated_at: updated_at,
        next: fn(result) {
          case result {
            Ok(config) -> program_types.Pure(config)
            Error(err) -> program_types.Fail(err)
          }
        },
      ),
    ),
  )
}
