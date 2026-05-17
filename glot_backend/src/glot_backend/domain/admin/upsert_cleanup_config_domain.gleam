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
import glot_core/admin/cleanup_config_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/validation_error

pub fn upsert_cleanup_config(
  ctx: context.Context,
  request: cleanup_config_dto.UpsertCleanupConfigRequest,
) -> program_types.Program(cleanup_config_dto.CleanupConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpsertAdminCleanupConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use _ <- program.and_then(app_config_effect.upsert_cleanup_config(
    dynamic_config.CleanupConfig(
      api_log_retention_days: request.api_log_retention_days,
      page_log_retention_days: request.page_log_retention_days,
      pageview_log_retention_days: request.pageview_log_retention_days,
      run_log_retention_days: request.run_log_retention_days,
      job_log_retention_days: request.job_log_retention_days,
      jobs_retention_days: request.jobs_retention_days,
      login_tokens_retention_days: request.login_tokens_retention_days,
      user_actions_retention_days: request.user_actions_retention_days,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(cleanup_config_dto.CleanupConfigResponse(
    api_log_retention_days: request.api_log_retention_days,
    page_log_retention_days: request.page_log_retention_days,
    pageview_log_retention_days: request.pageview_log_retention_days,
    run_log_retention_days: request.run_log_retention_days,
    job_log_retention_days: request.job_log_retention_days,
    jobs_retention_days: request.jobs_retention_days,
    login_tokens_retention_days: request.login_tokens_retention_days,
    user_actions_retention_days: request.user_actions_retention_days,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(cleanup_config_dto.UpsertCleanupConfigRequest) {
  program.decode_dynamic(data, cleanup_config_dto.decoder())
}

fn validate_request(
  request: cleanup_config_dto.UpsertCleanupConfigRequest,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(require_positive(
    request.api_log_retention_days,
    "api_log_retention_days",
  ))
  use _ <- program.and_then(require_positive(
    request.page_log_retention_days,
    "page_log_retention_days",
  ))
  use _ <- program.and_then(require_positive(
    request.pageview_log_retention_days,
    "pageview_log_retention_days",
  ))
  use _ <- program.and_then(require_positive(
    request.run_log_retention_days,
    "run_log_retention_days",
  ))
  use _ <- program.and_then(require_positive(
    request.job_log_retention_days,
    "job_log_retention_days",
  ))
  use _ <- program.and_then(require_positive(
    request.jobs_retention_days,
    "jobs_retention_days",
  ))
  use _ <- program.and_then(require_positive(
    request.login_tokens_retention_days,
    "login_tokens_retention_days",
  ))
  use _ <- program.and_then(require_positive(
    request.user_actions_retention_days,
    "user_actions_retention_days",
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
