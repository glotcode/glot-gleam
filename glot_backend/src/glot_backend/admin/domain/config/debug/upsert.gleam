import gleam/dynamic
import gleam/option
import glot_backend/app_config/effect/effect as app_config_effect
import glot_backend/app_config/model/system_config
import glot_backend/auth/domain/session/current as current_session
import glot_backend/request_policy/api_action as api_action_policy
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/hydrated_context as request_context
import glot_backend/user_action/effect/effect as user_action_effect
import glot_core/admin/debug_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn upsert_debug_config(
  request_ctx: request_context.RequestContext,
  request: debug_config_dto.UpsertDebugConfigRequest,
) -> program_types.Program(debug_config_dto.DebugConfigResponse) {
  let ctx = request_ctx.context

  use session <- program.and_then(current_session.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.UpsertAdminDebugConfigAction),
    actor: api_action_policy.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(app_config_effect.upsert_debug_config(
    system_config.DebugConfig(enabled: request.enabled),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(debug_config_dto.DebugConfigResponse(enabled: request.enabled))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(debug_config_dto.UpsertDebugConfigRequest) {
  program.decode_dynamic(data, debug_config_dto.decoder())
}
