import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/language_version_cache_worker_config_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/validation_error

const max_refresh_interval_ms = 86_400_000

const max_refresh_step_delay_ms = 60_000

const max_refresh_step_jitter_ms = 60_000

const max_default_timeout_ms = 600_000

pub fn upsert_language_version_cache_worker_config(
  ctx: context.Context,
  request: language_version_cache_worker_config_dto.UpsertLanguageVersionCacheWorkerConfigRequest,
) -> program_types.Program(
  language_version_cache_worker_config_dto.LanguageVersionCacheWorkerConfigResponse,
) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(
      admin_action.UpsertAdminLanguageVersionCacheWorkerConfigAction,
    ),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use _ <- program.and_then(
    app_config_effect.upsert_language_version_cache_worker_config(
      dynamic_config.LanguageVersionCacheWorkerConfig(
        refresh_interval_ms: request.refresh_interval_ms,
        refresh_step_delay_ms: request.refresh_step_delay_ms,
        refresh_step_jitter_ms: request.refresh_step_jitter_ms,
        default_timeout_ms: request.default_timeout_ms,
      ),
      ctx.timestamp,
    ),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(
    language_version_cache_worker_config_dto.LanguageVersionCacheWorkerConfigResponse(
      refresh_interval_ms: request.refresh_interval_ms,
      refresh_step_delay_ms: request.refresh_step_delay_ms,
      refresh_step_jitter_ms: request.refresh_step_jitter_ms,
      default_timeout_ms: request.default_timeout_ms,
    ),
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(
  language_version_cache_worker_config_dto.UpsertLanguageVersionCacheWorkerConfigRequest,
) {
  program.decode_dynamic(
    data,
    language_version_cache_worker_config_dto.decoder(),
  )
}

fn validate_request(
  request: language_version_cache_worker_config_dto.UpsertLanguageVersionCacheWorkerConfigRequest,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(require_positive(
    request.refresh_interval_ms,
    "refresh_interval_ms",
  ))
  use _ <- program.and_then(require_positive(
    request.refresh_step_delay_ms,
    "refresh_step_delay_ms",
  ))
  use _ <- program.and_then(require_positive(
    request.default_timeout_ms,
    "default_timeout_ms",
  ))
  use _ <- program.and_then(require_non_negative(
    request.refresh_step_jitter_ms,
    "refresh_step_jitter_ms",
  ))
  use _ <- program.and_then(require_max(
    request.refresh_interval_ms,
    "refresh_interval_ms",
    max_refresh_interval_ms,
  ))
  use _ <- program.and_then(require_max(
    request.refresh_step_delay_ms,
    "refresh_step_delay_ms",
    max_refresh_step_delay_ms,
  ))
  use _ <- program.and_then(require_max(
    request.refresh_step_jitter_ms,
    "refresh_step_jitter_ms",
    max_refresh_step_jitter_ms,
  ))
  use _ <- program.and_then(require_max(
    request.default_timeout_ms,
    "default_timeout_ms",
    max_default_timeout_ms,
  ))

  program.succeed(Nil)
}

fn require_positive(value: Int, field: String) -> program_types.Program(Nil) {
  case value > 0 {
    True -> program.succeed(Nil)
    False ->
      program.fail(
        error.validation(validation_error.MustBeGreaterThan(field, 0)),
      )
  }
}

fn require_non_negative(
  value: Int,
  field: String,
) -> program_types.Program(Nil) {
  case value >= 0 {
    True -> program.succeed(Nil)
    False ->
      program.fail(
        error.validation(validation_error.MustBeGreaterThanOrEqual(field, 0)),
      )
  }
}

fn require_max(
  value: Int,
  field: String,
  max: Int,
) -> program_types.Program(Nil) {
  case value <= max {
    True -> program.succeed(Nil)
    False ->
      program.fail(
        error.validation(validation_error.MustBeLessThanOrEqual(field, max)),
      )
  }
}
