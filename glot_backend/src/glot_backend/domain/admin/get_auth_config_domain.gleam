import gleam/option
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/request_context
import glot_core/admin/auth_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_auth_config(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(auth_config_dto.AuthConfigResponse) {
  let config = request_ctx.dynamic_config

  use session <- program.and_then(session_domain.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.GetAdminAuthConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  let auth_config = dynamic_config.auth_config(config)

  program.succeed(auth_config_dto.AuthConfigResponse(
    login_token_max_age: auth_config.login_token_max_age,
    session_token_max_age: auth_config.session_token_max_age,
    session_idle_timeout_seconds: auth_config.session_idle_timeout_seconds,
    session_cookie_max_age: auth_config.session_cookie_max_age,
    session_refresh_interval_seconds: auth_config.session_refresh_interval_seconds,
    session_previous_token_grace_seconds: auth_config.session_previous_token_grace_seconds,
    session_heartbeat_interval_seconds: auth_config.session_heartbeat_interval_seconds,
  ))
}
