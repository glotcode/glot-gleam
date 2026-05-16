import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/log_worker_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_log_worker_config(
  ctx: context.Context,
) -> program_types.Program(log_worker_config_dto.LogWorkerConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminLogWorkerConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let log_worker_config = dynamic_config.log_worker_config(config)
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(log_worker_config_dto.LogWorkerConfigResponse(
    flush_interval_ms: log_worker_config.flush_interval_ms,
    max_batch_size: log_worker_config.max_batch_size,
    max_buffer_size: log_worker_config.max_buffer_size,
  ))
}
