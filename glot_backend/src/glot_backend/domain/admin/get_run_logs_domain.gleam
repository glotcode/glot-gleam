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
import glot_core/admin/run_log_dto
import glot_core/api_action
import glot_core/pagination_model
import glot_core/run_log_model

pub fn get_run_logs(
  ctx: context.Context,
  request: run_log_dto.ListRunLogsRequest,
) -> program_types.Program(run_log_dto.ListRunLogsResponse) {
  let pagination = request.pagination
  use _ <- program.and_then(
    pagination_model.validate(pagination, 100)
    |> result.map_error(error.ValidationError)
    |> program.from_result,
  )
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(api_action.GetAdminRunLogsAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use logs <- program.and_then(admin_log_effect.list_run_logs(
    run_log_dto.ListRunLogsRequest(
      ..request,
      pagination: pagination_model.increment_limit(pagination),
    ),
  ))

  let page = pagination_model.paginate(logs, pagination, run_log_model.cursor)

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(run_log_dto.from_run_logs(page))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(run_log_dto.ListRunLogsRequest) {
  program.decode_dynamic(data, run_log_dto.list_request_decoder())
}
