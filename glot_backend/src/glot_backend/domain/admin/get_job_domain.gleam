import gleam/dynamic
import gleam/option
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/error
import glot_backend/effect/error/resource_error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/request_context
import glot_core/admin/job_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_job(
  request_ctx: request_context.RequestContext,
  request: job_dto.GetJobRequest,
) -> program_types.Program(job_dto.GetJobResponse) {
  let ctx = request_ctx.context

  use session <- program.and_then(session_domain.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.GetAdminJobAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use job <- program.and_then(
    job_effect.get_job_by_id(request.id)
    |> program.require(error.resource(resource_error.JobNotFound)),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(job_dto.from_job_detail(job, ctx.timestamp))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(job_dto.GetJobRequest) {
  program.decode_dynamic(data, job_dto.get_request_decoder())
}
