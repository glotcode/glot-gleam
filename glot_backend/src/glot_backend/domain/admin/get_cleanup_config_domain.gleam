import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/cleanup_config_dto
import glot_core/api_action
import glot_core/admin_action

pub fn get_cleanup_config(
  ctx: context.Context,
) -> program_types.Program(cleanup_config_dto.CleanupConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminCleanupConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let cleanup_config = dynamic_config.cleanup_config(config)
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(cleanup_config_dto.CleanupConfigResponse(
    api_log_retention_days: cleanup_config.api_log_retention_days,
    page_log_retention_days: cleanup_config.page_log_retention_days,
    pageview_log_retention_days: cleanup_config.pageview_log_retention_days,
    run_log_retention_days: cleanup_config.run_log_retention_days,
    job_log_retention_days: cleanup_config.job_log_retention_days,
    jobs_retention_days: cleanup_config.jobs_retention_days,
    login_tokens_retention_days: cleanup_config.login_tokens_retention_days,
    user_actions_retention_days: cleanup_config.user_actions_retention_days,
  ))
}
