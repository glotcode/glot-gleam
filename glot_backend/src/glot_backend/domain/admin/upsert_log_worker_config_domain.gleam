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
import glot_core/admin/log_worker_config_dto
import glot_core/admin_action
import glot_core/api_action

const max_flush_interval_ms = 60_000
const max_batch_size_limit = 10_000
const max_buffer_size_limit = 100_000

pub fn upsert_log_worker_config(
  ctx: context.Context,
  request: log_worker_config_dto.UpsertLogWorkerConfigRequest,
) -> program_types.Program(log_worker_config_dto.LogWorkerConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpsertAdminLogWorkerConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use _ <- program.and_then(app_config_effect.upsert_log_worker_config(
    dynamic_config.LogWorkerConfig(
      flush_interval_ms: request.flush_interval_ms,
      max_batch_size: request.max_batch_size,
      max_buffer_size: request.max_buffer_size,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(log_worker_config_dto.LogWorkerConfigResponse(
    flush_interval_ms: request.flush_interval_ms,
    max_batch_size: request.max_batch_size,
    max_buffer_size: request.max_buffer_size,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(log_worker_config_dto.UpsertLogWorkerConfigRequest) {
  program.decode_dynamic(data, log_worker_config_dto.decoder())
}

fn validate_request(
  request: log_worker_config_dto.UpsertLogWorkerConfigRequest,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(require(
    !list.any(
      [
        request.flush_interval_ms,
        request.max_batch_size,
        request.max_buffer_size,
      ],
      fn(value) { value <= 0 },
    ),
    "log worker config values must be greater than 0",
  ))
  use _ <- program.and_then(require(
    request.flush_interval_ms <= max_flush_interval_ms,
    "flush interval must be less than or equal to 60000 ms",
  ))
  use _ <- program.and_then(require(
    request.max_batch_size <= max_batch_size_limit,
    "max batch size must be less than or equal to 10000",
  ))
  use _ <- program.and_then(require(
    request.max_buffer_size <= max_buffer_size_limit,
    "max buffer size must be less than or equal to 100000",
  ))
  use _ <- program.and_then(require(
    request.max_buffer_size >= request.max_batch_size,
    "max buffer size must be greater than or equal to max batch size",
  ))

  program.succeed(Nil)
}

fn require(condition: Bool, message: String) -> program_types.Program(Nil) {
  case condition {
    True -> program.succeed(Nil)
    False -> program.fail(error.ValidationError(message))
  }
}
