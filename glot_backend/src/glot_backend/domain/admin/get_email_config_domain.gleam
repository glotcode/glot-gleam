import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/email_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_email_config(
  ctx: context.Context,
) -> program_types.Program(email_config_dto.EmailConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminEmailConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(email_config_dto.EmailConfigResponse(
    from_address: dynamic_config.email_config(config).from_address,
    from_name: dynamic_config.email_config(config).from_name,
  ))
}
