import gleam/dynamic
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
import glot_core/validation_error

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
  use _ <- program.and_then(require_positive(
    request.flush_interval_ms,
    "flush_interval_ms",
  ))
  use _ <- program.and_then(require_positive(
    request.max_batch_size,
    "max_batch_size",
  ))
  use _ <- program.and_then(require_positive(
    request.max_buffer_size,
    "max_buffer_size",
  ))
  use _ <- program.and_then(require_max(
    request.flush_interval_ms,
    "flush_interval_ms",
    max_flush_interval_ms,
  ))
  use _ <- program.and_then(require_max(
    request.max_batch_size,
    "max_batch_size",
    max_batch_size_limit,
  ))
  use _ <- program.and_then(require_max(
    request.max_buffer_size,
    "max_buffer_size",
    max_buffer_size_limit,
  ))
  use _ <- program.and_then(require_gte_field(
    request.max_buffer_size,
    "max_buffer_size",
    request.max_batch_size,
    "max_batch_size",
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

fn require_max(
  value: Int,
  field: String,
  max: Int,
) -> program_types.Program(Nil) {
  case value <= max {
    True -> program.succeed(Nil)
    False ->
      program.fail(
        error.validation(validation_error.MustBeLessThanOrEqual(field, max)),
      )
  }
}

fn require_gte_field(
  value: Int,
  field: String,
  other_value: Int,
  other_field: String,
) -> program_types.Program(Nil) {
  case value >= other_value {
    True -> program.succeed(Nil)
    False ->
      program.fail(
        error.validation(validation_error.MustBeGreaterThanOrEqualField(
          field,
          other_field,
        )),
      )
  }
}
