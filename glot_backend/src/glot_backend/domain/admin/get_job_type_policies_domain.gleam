import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/job_type_policy/job_type_policy_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/job_type_policy_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_job_type_policies(
  ctx: context.Context,
) -> program_types.Program(job_type_policy_dto.ListJobTypePoliciesResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminJobTypePoliciesAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use policies <- program.and_then(
    job_type_policy_effect.list_job_type_policies(),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(job_type_policy_dto.from_job_type_policies(policies))
}
