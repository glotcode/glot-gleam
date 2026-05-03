import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/shared/admin_authorization_domain
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

pub fn get_auth_config(
  ctx: context.Context,
) -> program_types.Program(auth_config_dto.AuthConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use _ <- program.and_then(admin_authorization_domain.require_admin(session))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.GetAdminAuthConfigAction,
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  use auth_config <- program.and_then(
    dynamic_config.require_auth_config(config)
    |> result.map_error(fn(message) {
      error.QueryError(error.DbQueryError(message))
    })
    |> program.from_result(),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(auth_config_dto.AuthConfigResponse(
    login_token_max_age: auth_config.login_token_max_age,
    session_token_max_age: auth_config.session_token_max_age,
    session_cookie_max_age: auth_config.session_cookie_max_age,
  ))
}
