import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/admin_log/admin_log_effect
import glot_backend/effect/error
import glot_backend/effect/error/resource_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/run_log_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_run_log(
  ctx: context.Context,
  request: run_log_dto.GetRunLogRequest,
) -> program_types.Program(run_log_dto.GetRunLogResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminRunLogAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use log <- program.and_then(
    admin_log_effect.get_run_log(request.id)
    |> program.require(error.resource(resource_error.RunLogNotFound)),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(run_log_dto.from_run_log_detail(log))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(run_log_dto.GetRunLogRequest) {
  program.decode_dynamic(data, run_log_dto.get_request_decoder())
}
