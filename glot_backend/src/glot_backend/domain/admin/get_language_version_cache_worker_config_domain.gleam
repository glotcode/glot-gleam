import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/language_version_cache_worker_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_language_version_cache_worker_config(
  ctx: context.Context,
) -> program_types.Program(
  language_version_cache_worker_config_dto.LanguageVersionCacheWorkerConfigResponse,
) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(
      admin_action.GetAdminLanguageVersionCacheWorkerConfigAction,
    ),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let worker_config =
    dynamic_config.language_version_cache_worker_config(config)
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(
    language_version_cache_worker_config_dto.LanguageVersionCacheWorkerConfigResponse(
      refresh_interval_ms: worker_config.refresh_interval_ms,
      refresh_step_delay_ms: worker_config.refresh_step_delay_ms,
      refresh_step_jitter_ms: worker_config.refresh_step_jitter_ms,
      default_timeout_ms: worker_config.default_timeout_ms,
    ),
  )
}
