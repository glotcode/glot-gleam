import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/admin_authorization_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/admin_log/admin_log_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/job_log_dto
import glot_core/api_action

pub fn get_job_log(
  ctx: context.Context,
  request: job_log_dto.GetJobLogRequest,
) -> program_types.Program(job_log_dto.GetJobLogResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use _ <- program.and_then(admin_authorization_domain.require_admin(session))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.GetAdminJobLogAction,
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use log <- program.and_then(
    admin_log_effect.get_job_log(request.id)
    |> program.require(error.NotFoundError(
      "job_log_not_found",
      "Job log not found",
    )),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(job_log_dto.from_job_log_detail(log))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(job_log_dto.GetJobLogRequest) {
  program.decode_dynamic(data, job_log_dto.get_request_decoder())
}
