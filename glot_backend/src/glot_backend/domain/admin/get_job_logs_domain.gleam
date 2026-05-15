import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/admin_log/admin_log_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/job_log_dto
import glot_core/api_action
import glot_core/job_log_model
import glot_core/pagination_model

pub fn get_job_logs(
  ctx: context.Context,
  request: job_log_dto.ListJobLogsRequest,
) -> program_types.Program(job_log_dto.ListJobLogsResponse) {
  let pagination = request.pagination
  use _ <- program.and_then(
    pagination_model.validate(pagination, 100)
    |> result.map_error(error.ValidationError)
    |> program.from_result,
  )
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(api_action.GetAdminJobLogsAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use logs <- program.and_then(admin_log_effect.list_job_logs(
    job_log_dto.ListJobLogsRequest(
      ..request,
      pagination: pagination_model.increment_limit(pagination),
    ),
  ))

  let page = pagination_model.paginate(logs, pagination, job_log_model.cursor)

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(job_log_dto.from_job_logs(page))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(job_log_dto.ListJobLogsRequest) {
  program.decode_dynamic(data, job_log_dto.list_request_decoder())
}
