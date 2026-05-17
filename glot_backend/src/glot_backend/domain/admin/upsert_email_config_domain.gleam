import gleam/dynamic
import gleam/option
import gleam/string
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/email_config_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/email/email_address_model
import glot_core/validation_error

const max_default_timeout_ms = 600_000

pub fn upsert_email_config(
  ctx: context.Context,
  request: email_config_dto.UpsertEmailConfigRequest,
) -> program_types.Program(email_config_dto.EmailConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpsertAdminEmailConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(ctx, request))
  let from_name = normalize_from_name(request.from_name)
  use _ <- program.and_then(app_config_effect.upsert_email_config(
    dynamic_config.EmailConfig(
      from_address: request.from_address,
      from_name: from_name,
      default_timeout_ms: request.default_timeout_ms,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(email_config_dto.EmailConfigResponse(
    from_address: request.from_address,
    from_name: from_name,
    default_timeout_ms: request.default_timeout_ms,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(email_config_dto.UpsertEmailConfigRequest) {
  program.decode_dynamic(data, email_config_dto.decoder())
}

fn validate_request(
  ctx: context.Context,
  request: email_config_dto.UpsertEmailConfigRequest,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(require_positive(
    request.default_timeout_ms,
    "default_timeout_ms",
  ))
  use _ <- program.and_then(require_max(
    request.default_timeout_ms,
    "default_timeout_ms",
    max_default_timeout_ms,
  ))

  case string.trim(request.from_address) {
    "" ->
      program.fail(error.validation(validation_error.EmptyField("fromAddress")))
    _ ->
      case
        email_address_model.from_string(
          ctx.regexes.is_email,
          request.from_address,
        )
      {
        option.Some(_) -> program.succeed(Nil)
        option.None ->
          program.fail(
            error.validation(validation_error.InvalidEmail("fromAddress")),
          )
      }
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

fn normalize_from_name(value: option.Option(String)) -> option.Option(String) {
  case value {
    option.Some(name) ->
      case string.trim(name) {
        "" -> option.None
        trimmed -> option.Some(trimmed)
      }
    option.None -> option.None
  }
}
