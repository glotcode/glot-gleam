import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/periodic_job/periodic_job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/periodic_job_dto
import glot_core/api_action

pub fn get_periodic_jobs(
  ctx: context.Context,
) -> program_types.Program(periodic_job_dto.ListPeriodicJobsResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.GetAdminPeriodicJobsAction,
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use periodic_jobs <- program.and_then(
    periodic_job_effect.list_periodic_jobs(),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(periodic_job_dto.from_periodic_jobs(periodic_jobs))
}
