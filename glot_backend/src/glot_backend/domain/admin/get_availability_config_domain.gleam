import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/availability_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_availability_config(
  ctx: context.Context,
) -> program_types.Program(availability_config_dto.AvailabilityConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminAvailabilityConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  let availability = dynamic_config.availability_config(config)

  program.succeed(availability_config_dto.AvailabilityConfigResponse(
    mode: availability.mode,
    message: availability.message,
    retry_after_seconds: availability.retry_after_seconds,
  ))
}
