import gleam/dynamic
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

pub fn upsert_availability_config(
  ctx: context.Context,
  request: availability_config_dto.UpsertAvailabilityConfigRequest,
) -> program_types.Program(availability_config_dto.AvailabilityConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpsertAdminAvailabilityConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(app_config_effect.upsert_availability_config(
    dynamic_config.AvailabilityConfig(
      mode: request.mode,
      message: request.message,
      retry_after_seconds: request.retry_after_seconds,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(availability_config_dto.AvailabilityConfigResponse(
    mode: request.mode,
    message: request.message,
    retry_after_seconds: request.retry_after_seconds,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(availability_config_dto.UpsertAvailabilityConfigRequest) {
  program.decode_dynamic(data, availability_config_dto.decoder())
}
