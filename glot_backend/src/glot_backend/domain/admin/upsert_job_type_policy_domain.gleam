import gleam/dynamic
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/error
import glot_backend/effect/job_type_policy/job_type_policy_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/job_type_policy_dto
import glot_core/api_action
import glot_core/admin_action
import glot_core/job/job_model

pub fn upsert_job_type_policy(
  ctx: context.Context,
  request: job_type_policy_dto.UpsertJobTypePolicyRequest,
) -> program_types.Program(job_type_policy_dto.JobTypePolicyResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpsertAdminJobTypePolicyAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use policy <- program.and_then(policy_from_request(request, ctx.timestamp))
  use _ <- program.and_then(validate_policy(policy))
  use _ <- program.and_then(job_type_policy_effect.upsert_job_type_policy(
    policy,
    ctx.timestamp,
  ))
  use saved_policy <- program.and_then(
    job_type_policy_effect.get_job_type_policy_by_job_type(policy.job_type)
    |> program.require(error.NotFoundError(
      "job_type_policy_not_found",
      "Job type policy not found",
    )),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(job_type_policy_dto.from_job_type_policy(saved_policy))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(job_type_policy_dto.UpsertJobTypePolicyRequest) {
  program.decode_dynamic(data, job_type_policy_dto.request_decoder())
}

fn policy_from_request(
  request: job_type_policy_dto.UpsertJobTypePolicyRequest,
  now: Timestamp,
) -> program_types.Program(job_model.JobTypePolicy) {
  case job_model.job_type_from_string(request.job_type) {
    Ok(job_type) ->
      program.succeed(job_model.JobTypePolicy(
        job_type: job_type,
        max_attempts: request.max_attempts,
        timeout_seconds: request.timeout_seconds,
        base_backoff_seconds: request.base_backoff_seconds,
        max_backoff_seconds: request.max_backoff_seconds,
        created_at: now,
        updated_at: now,
      ))
    Error(message) -> program.fail(error.ValidationError(message))
  }
}

fn validate_policy(
  policy: job_model.JobTypePolicy,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(require(
    policy.max_attempts > 0,
    "max_attempts must be greater than 0",
  ))
  use _ <- program.and_then(require(
    policy.timeout_seconds > 0,
    "timeout_seconds must be greater than 0",
  ))
  use _ <- program.and_then(require(
    policy.base_backoff_seconds > 0,
    "base_backoff_seconds must be greater than 0",
  ))
  use _ <- program.and_then(require(
    policy.max_backoff_seconds > 0,
    "max_backoff_seconds must be greater than 0",
  ))
  use _ <- program.and_then(require(
    policy.base_backoff_seconds <= policy.max_backoff_seconds,
    "base_backoff_seconds must be less than or equal to max_backoff_seconds",
  ))

  program.succeed(Nil)
}

fn require(condition: Bool, message: String) -> program_types.Program(Nil) {
  case condition {
    True -> program.succeed(Nil)
    False -> program.fail(error.ValidationError(message))
  }
}
