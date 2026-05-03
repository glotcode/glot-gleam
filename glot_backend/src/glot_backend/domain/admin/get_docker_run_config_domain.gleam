import gleam/option
import glot_backend/context
import glot_backend/domain/shared/admin_authorization_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/docker_run_config_dto
import glot_core/api_action

pub fn get_docker_run_config(
  ctx: context.Context,
) -> program_types.Program(docker_run_config_dto.DockerRunConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use _ <- program.and_then(admin_authorization_domain.require_admin(session))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.GetAdminDockerRunConfigAction,
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  use docker_run_config <- program.and_then(program.from_option(
    dynamic_config.lookup_docker_run_config(config),
    error.NotFoundError(
      code: "docker_run_config_not_found",
      message: "Docker run config is not configured",
    ),
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
  )
}
