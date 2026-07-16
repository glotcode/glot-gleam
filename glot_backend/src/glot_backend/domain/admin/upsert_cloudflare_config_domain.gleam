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
import glot_core/admin/cloudflare_config_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/validation_error

pub fn upsert_cloudflare_config(
  request_ctx: request_context.RequestContext,
  request: cloudflare_config_dto.UpsertCloudflareConfigRequest,
) -> program_types.Program(cloudflare_config_dto.CloudflareConfigResponse) {
  let ctx = request_ctx.context

  use session <- program.and_then(session_domain.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.UpsertAdminCloudflareConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use _ <- program.and_then(app_config_effect.upsert_cloudflare_config(
    dynamic_config.CloudflareConfig(
      account_id: request.account_id,
      api_token: request.api_token,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(cloudflare_config_dto.CloudflareConfigResponse(
    account_id: request.account_id,
    api_token: request.api_token,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(cloudflare_config_dto.UpsertCloudflareConfigRequest) {
  program.decode_dynamic(data, cloudflare_config_dto.decoder())
}

fn validate_request(
  request: cloudflare_config_dto.UpsertCloudflareConfigRequest,
) -> program_types.Program(Nil) {
  case string.trim(request.account_id), string.trim(request.api_token) {
    "", _ ->
      program.fail(error.validation(validation_error.EmptyField("accountId")))
    _, "" ->
      program.fail(error.validation(validation_error.EmptyField("apiToken")))
    _, _ -> program.succeed(Nil)
  }
}
