import gleam/dynamic
import gleam/option
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/request_context
import glot_core/admin/auth_config_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/validation_error

pub fn upsert_auth_config(
  request_ctx: request_context.RequestContext,
  request: auth_config_dto.UpsertAuthConfigRequest,
) -> program_types.Program(auth_config_dto.AuthConfigResponse) {
  let ctx = request_ctx.context

  use session <- program.and_then(session_domain.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.UpsertAdminAuthConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use _ <- program.and_then(app_config_effect.upsert_auth_config(
    dynamic_config.AuthConfig(
      login_token_max_age: request.login_token_max_age,
      session_token_max_age: request.session_token_max_age,
      session_idle_timeout_seconds: request.session_idle_timeout_seconds,
      session_cookie_max_age: request.session_cookie_max_age,
      session_refresh_interval_seconds: request.session_refresh_interval_seconds,
      session_previous_token_grace_seconds: request.session_previous_token_grace_seconds,
      session_heartbeat_interval_seconds: request.session_heartbeat_interval_seconds,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(auth_config_dto.AuthConfigResponse(
    login_token_max_age: request.login_token_max_age,
    session_token_max_age: request.session_token_max_age,
    session_idle_timeout_seconds: request.session_idle_timeout_seconds,
    session_cookie_max_age: request.session_cookie_max_age,
    session_refresh_interval_seconds: request.session_refresh_interval_seconds,
    session_previous_token_grace_seconds: request.session_previous_token_grace_seconds,
    session_heartbeat_interval_seconds: request.session_heartbeat_interval_seconds,
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
  use _ <- program.and_then(require_positive(
    request.login_token_max_age,
    "login_token_max_age",
  ))
  use _ <- program.and_then(require_positive(
    request.session_token_max_age,
    "session_token_max_age",
  ))
  use _ <- program.and_then(require_positive(
    request.session_idle_timeout_seconds,
    "session_idle_timeout_seconds",
  ))
  use _ <- program.and_then(require_positive(
    request.session_cookie_max_age,
    "session_cookie_max_age",
  ))
  use _ <- program.and_then(require_positive(
    request.session_refresh_interval_seconds,
    "session_refresh_interval_seconds",
  ))
  use _ <- program.and_then(require_positive(
    request.session_previous_token_grace_seconds,
    "session_previous_token_grace_seconds",
  ))
  use _ <- program.and_then(require_positive(
    request.session_heartbeat_interval_seconds,
    "session_heartbeat_interval_seconds",
  ))
  use _ <- program.and_then(require_at_least(
    request.session_idle_timeout_seconds,
    request.session_heartbeat_interval_seconds,
    "session_idle_timeout_seconds",
    "session_heartbeat_interval_seconds",
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

fn require_at_least(
  value: Int,
  minimum: Int,
  field: String,
  minimum_field: String,
) -> program_types.Program(Nil) {
  case value >= minimum {
    True -> program.succeed(Nil)
    False ->
      program.fail(
        error.validation(validation_error.MustBeGreaterThanOrEqualField(
          field,
          minimum_field,
        )),
      )
  }
}
