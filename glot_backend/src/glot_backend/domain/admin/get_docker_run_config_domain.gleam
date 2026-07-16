import gleam/option
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/error
import glot_backend/effect/error/resource_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/request_context
import glot_core/admin/docker_run_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_docker_run_config(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(docker_run_config_dto.DockerRunConfigResponse) {
  let config = request_ctx.dynamic_config

  use session <- program.and_then(session_domain.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.GetAdminDockerRunConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use docker_run_config <- program.and_then(program.from_option(
    dynamic_config.docker_run_config(config),
    error.resource(resource_error.DockerRunConfigNotFound),
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(response_from_dynamic_config(docker_run_config))
}

fn response_from_dynamic_config(
  config: dynamic_config.DockerRunConfig,
) -> docker_run_config_dto.DockerRunConfigResponse {
  docker_run_config_dto.DockerRunConfigResponse(
    base_url: config.base_url,
    access_token: config.access_token,
    default_timeout_ms: config.default_timeout_ms,
  )
}
