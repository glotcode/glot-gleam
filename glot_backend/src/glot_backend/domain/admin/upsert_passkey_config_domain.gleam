import gleam/dynamic
import gleam/option
import gleam/string
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/request_context
import glot_core/admin/passkey_config_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/validation_error

pub fn upsert_passkey_config(
  request_ctx: request_context.RequestContext,
  request: passkey_config_dto.UpsertPasskeyConfigRequest,
) -> program_types.Program(passkey_config_dto.PasskeyConfigResponse) {
  let ctx = request_ctx.context

  use session <- program.and_then(session_domain.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.UpsertAdminPasskeyConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  let origin = string.trim(request.origin)
  let rp_id = string.trim(request.rp_id)
  use _ <- program.and_then(app_config_effect.upsert_passkey_config(
    dynamic_config.PasskeyConfig(
      origin: origin,
      rp_id: rp_id,
      challenge_timeout_seconds: request.challenge_timeout_seconds,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(passkey_config_dto.PasskeyConfigResponse(
    origin: origin,
    rp_id: rp_id,
    challenge_timeout_seconds: request.challenge_timeout_seconds,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(passkey_config_dto.UpsertPasskeyConfigRequest) {
  program.decode_dynamic(data, passkey_config_dto.decoder())
}

fn validate_request(
  request: passkey_config_dto.UpsertPasskeyConfigRequest,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(require_non_empty(request.origin, "origin"))
  use _ <- program.and_then(require_non_empty(request.rp_id, "rpId"))
  use _ <- program.and_then(require_positive(
    request.challenge_timeout_seconds,
    "challenge_timeout_seconds",
  ))
  program.succeed(Nil)
}

fn require_non_empty(
  value: String,
  field: String,
) -> program_types.Program(Nil) {
  case string.trim(value) {
    "" -> program.fail(error.validation(validation_error.EmptyField(field)))
    _ -> program.succeed(Nil)
  }
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
