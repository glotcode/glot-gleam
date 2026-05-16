import gleam/dynamic
import gleam/list
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
import glot_core/admin/auth_config_dto
import glot_core/api_action
import glot_core/admin_action

pub fn upsert_auth_config(
  ctx: context.Context,
  request: auth_config_dto.UpsertAuthConfigRequest,
) -> program_types.Program(auth_config_dto.AuthConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpsertAdminAuthConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use _ <- program.and_then(app_config_effect.upsert_auth_config(
    dynamic_config.AuthConfig(
      login_token_max_age: request.login_token_max_age,
      session_token_max_age: request.session_token_max_age,
      session_cookie_max_age: request.session_cookie_max_age,
      session_refresh_interval_seconds: request.session_refresh_interval_seconds,
      session_previous_token_grace_seconds:
        request.session_previous_token_grace_seconds,
      session_heartbeat_interval_seconds:
        request.session_heartbeat_interval_seconds,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(auth_config_dto.AuthConfigResponse(
    login_token_max_age: request.login_token_max_age,
    session_token_max_age: request.session_token_max_age,
    session_cookie_max_age: request.session_cookie_max_age,
    session_refresh_interval_seconds: request.session_refresh_interval_seconds,
    session_previous_token_grace_seconds:
      request.session_previous_token_grace_seconds,
    session_heartbeat_interval_seconds:
      request.session_heartbeat_interval_seconds,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(auth_config_dto.UpsertAuthConfigRequest) {
  program.decode_dynamic(data, auth_config_dto.decoder())
}

fn validate_request(
  request: auth_config_dto.UpsertAuthConfigRequest,
) -> program_types.Program(Nil) {
  case
    list.any(
      [
        request.login_token_max_age,
        request.session_token_max_age,
        request.session_cookie_max_age,
        request.session_refresh_interval_seconds,
        request.session_previous_token_grace_seconds,
        request.session_heartbeat_interval_seconds,
      ],
      fn(value) { value <= 0 },
    )
  {
    True ->
      program.fail(error.ValidationError(
        "auth config values must be greater than 0",
      ))
    False -> program.succeed(Nil)
  }
}
