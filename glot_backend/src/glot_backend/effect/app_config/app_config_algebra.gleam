import gleam/time/timestamp.{type Timestamp}
import glot_backend/dynamic_config
import glot_backend/effect/error
import glot_core/api_action.{type PublicAction}

pub type AppConfigEffect(next) {
  GetDynamicConfig(
    next: fn(Result(dynamic_config.DynamicConfig, error.DbQueryError)) -> next,
  )
  UpsertDebugConfig(
    config: dynamic_config.DebugConfig,
    updated_at: Timestamp,
    next: fn(Result(dynamic_config.DynamicConfig, error.Error)) -> next,
  )
  UpsertAuthConfig(
    config: dynamic_config.AuthConfig,
    updated_at: Timestamp,
    next: fn(Result(dynamic_config.DynamicConfig, error.Error)) -> next,
  )
  UpsertCleanupConfig(
    config: dynamic_config.CleanupConfig,
    updated_at: Timestamp,
    next: fn(Result(dynamic_config.DynamicConfig, error.Error)) -> next,
  )
  UpsertRateLimitPolicy(
    action: PublicAction,
    policy: dynamic_config.RateLimitPolicy,
    updated_at: Timestamp,
    next: fn(Result(dynamic_config.DynamicConfig, error.Error)) -> next,
  )
  UpsertDockerRunConfig(
    config: dynamic_config.DockerRunConfig,
    updated_at: Timestamp,
    next: fn(Result(dynamic_config.DynamicConfig, error.Error)) -> next,
  )
}

pub fn map(effect: AppConfigEffect(a), f: fn(a) -> b) -> AppConfigEffect(b) {
  case effect {
    GetDynamicConfig(next:) ->
      GetDynamicConfig(next: fn(value) { f(next(value)) })
    UpsertDebugConfig(config:, updated_at:, next:) ->
      UpsertDebugConfig(config: config, updated_at: updated_at, next: fn(value) {
        f(next(value))
      })
    UpsertAuthConfig(config:, updated_at:, next:) ->
      UpsertAuthConfig(config: config, updated_at: updated_at, next: fn(value) {
        f(next(value))
      })
    UpsertCleanupConfig(config:, updated_at:, next:) ->
      UpsertCleanupConfig(
        config: config,
        updated_at: updated_at,
        next: fn(value) { f(next(value)) },
      )
    UpsertRateLimitPolicy(action:, policy:, updated_at:, next:) ->
      UpsertRateLimitPolicy(
        action: action,
        policy: policy,
        updated_at: updated_at,
        next: fn(value) { f(next(value)) },
      )
    UpsertDockerRunConfig(config:, updated_at:, next:) ->
      UpsertDockerRunConfig(
        config: config,
        updated_at: updated_at,
        next: fn(value) { f(next(value)) },
      )
  }
}

pub type EffectName {
  GetDynamicConfigEffectName
  UpsertDebugConfigEffectName
  UpsertAuthConfigEffectName
  UpsertCleanupConfigEffectName
  UpsertRateLimitPolicyEffectName
  UpsertDockerRunConfigEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetDynamicConfigEffectName -> "get_dynamic_config"
    UpsertDebugConfigEffectName -> "upsert_debug_config"
    UpsertAuthConfigEffectName -> "upsert_auth_config"
    UpsertCleanupConfigEffectName -> "upsert_cleanup_config"
    UpsertRateLimitPolicyEffectName -> "upsert_rate_limit_policy"
    UpsertDockerRunConfigEffectName -> "upsert_docker_run_config"
  }
}
