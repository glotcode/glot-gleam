import gleam/option
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/auth/domain/session/current as current_session
import glot_backend/email/model/config as email_feature_config
import glot_backend/request_policy/api_action as api_action_policy
import glot_backend/system/effect/error
import glot_backend/system/effect/error/resource_error
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/hydrated_context as request_context
import glot_backend/user_action/effect/effect as user_action_effect
import glot_core/admin/cloudflare_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_cloudflare_config(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(cloudflare_config_dto.CloudflareConfigResponse) {
  let config = request_ctx.dynamic_config

  use session <- program.and_then(current_session.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.GetAdminCloudflareConfigAction),
    actor: api_action_policy.actor_from_user(option.Some(session.user)),
  ))
  use cloudflare_config <- program.and_then(program.from_option(
    dynamic_config.cloudflare_config(config),
    error.resource(resource_error.CloudflareConfigNotFound),
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(response_from_dynamic_config(cloudflare_config))
}

fn response_from_dynamic_config(
  config: email_feature_config.CloudflareConfig,
) -> cloudflare_config_dto.CloudflareConfigResponse {
  cloudflare_config_dto.CloudflareConfigResponse(
    account_id: config.account_id,
    api_token: config.api_token,
  )
}
