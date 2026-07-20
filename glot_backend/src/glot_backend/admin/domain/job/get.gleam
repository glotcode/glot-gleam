import gleam/dynamic
import gleam/option
import glot_backend/auth/domain/session/current as current_session
import glot_backend/job/effect/job/effect as job_effect
import glot_backend/request_policy/api_action as api_action_policy
import glot_backend/system/effect/error
import glot_backend/system/effect/error/resource_error
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/hydrated_context as request_context
import glot_backend/user_action/effect/effect as user_action_effect
import glot_core/admin/job_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_job(
  request_ctx: request_context.RequestContext,
  request: job_dto.GetJobRequest,
) -> program_types.Program(job_dto.GetJobResponse) {
  let ctx = request_ctx.context

  use session <- program.and_then(current_session.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.GetAdminJobAction),
    actor: api_action_policy.actor_from_user(option.Some(session.user)),
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
