import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/passkey_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_passkey_config(
  ctx: context.Context,
) -> program_types.Program(passkey_config_dto.PasskeyConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminPasskeyConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))
  let passkey_config = dynamic_config.passkey_config(config)

  program.succeed(passkey_config_dto.PasskeyConfigResponse(
    origin: passkey_config.origin,
    rp_id: passkey_config.rp_id,
    challenge_timeout_seconds: passkey_config.challenge_timeout_seconds,
  ))
}
