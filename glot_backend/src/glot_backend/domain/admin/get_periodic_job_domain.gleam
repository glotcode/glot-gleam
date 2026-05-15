import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/error
import glot_backend/effect/periodic_job/periodic_job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/periodic_job_dto
import glot_core/api_action

pub fn get_periodic_job(
  ctx: context.Context,
  request: periodic_job_dto.GetPeriodicJobRequest,
) -> program_types.Program(periodic_job_dto.GetPeriodicJobResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(api_action.GetAdminPeriodicJobAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use periodic_job <- program.and_then(
    periodic_job_effect.get_periodic_job_by_id(request.id)
    |> program.require(error.NotFoundError(
      "periodic_job_not_found",
      "Periodic job not found",
    )),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(periodic_job_dto.from_periodic_job_detail(periodic_job))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(periodic_job_dto.GetPeriodicJobRequest) {
  program.decode_dynamic(data, periodic_job_dto.get_request_decoder())
}
