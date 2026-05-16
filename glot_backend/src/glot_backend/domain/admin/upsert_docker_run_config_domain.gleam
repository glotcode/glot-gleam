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
import glot_core/admin/docker_run_config_dto
import glot_core/admin_action
import glot_core/api_action

pub fn upsert_docker_run_config(
  ctx: context.Context,
  request: docker_run_config_dto.UpsertDockerRunConfigRequest,
) -> program_types.Program(docker_run_config_dto.DockerRunConfigResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpsertAdminDockerRunConfigAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use _ <- program.and_then(app_config_effect.upsert_docker_run_config(
    dynamic_config.DockerRunConfig(
      base_url: request.base_url,
      access_token: request.access_token,
    ),
    ctx.timestamp,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(docker_run_config_dto.DockerRunConfigResponse(
    base_url: request.base_url,
    access_token: request.access_token,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(docker_run_config_dto.UpsertDockerRunConfigRequest) {
  program.decode_dynamic(data, docker_run_config_dto.decoder())
}

fn validate_request(
  request: docker_run_config_dto.UpsertDockerRunConfigRequest,
) -> program_types.Program(Nil) {
  case string.trim(request.base_url), string.trim(request.access_token) {
    "", _ -> program.fail(error.ValidationError("baseUrl must not be empty"))
    _, "" ->
      program.fail(error.ValidationError("accessToken must not be empty"))
    _, _ -> program.succeed(Nil)
  }
}
