import gleam/dynamic
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/domain/job/job_type_policy_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/job_dto
import glot_core/api_action
import glot_core/job/job_model
import youid/uuid.{type Uuid}

pub fn create_job(
  ctx: context.Context,
  request: job_dto.CreateJobRequest,
) -> program_types.Program(job_dto.GetJobResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.CreateAdminJobAction,
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use job_type <- program.and_then(
    validate_request(request)
    |> program.from_result(),
  )
  use job_id <- program.and_then(basic_effect.uuid_v7())
  use job_type_policy <- program.and_then(
    job_type_policy_domain.require_job_type_policy(job_type),
  )

  let job =
    new_job(
      request: request,
      job_type: job_type,
      job_type_policy: job_type_policy,
      job_id: job_id,
      request_id: ctx.request_id,
      now: ctx.timestamp,
    )

  use _ <- program.and_then(job_effect.create_job(job))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(job_dto.from_job_detail(job, ctx.timestamp))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(job_dto.CreateJobRequest) {
  program.decode_dynamic(data, job_dto.create_request_decoder())
}

fn validate_request(
  request: job_dto.CreateJobRequest,
) -> Result(job_model.JobType, error.Error) {
  case request.max_attempts > 0 {
    False ->
      Error(error.ValidationError("Max attempts must be greater than zero."))
    True ->
      case request.timeout_seconds > 0 {
        False ->
          Error(error.ValidationError(
            "Timeout seconds must be greater than zero.",
          ))
        True ->
          case job_model.job_type_from_string(request.job_type) {
            Ok(job_type) -> Ok(job_type)
            Error(message) -> Error(error.ValidationError(message))
          }
      }
  }
}

fn new_job(
  request request: job_dto.CreateJobRequest,
  job_type job_type: job_model.JobType,
  job_type_policy job_type_policy: job_model.JobTypePolicy,
  job_id job_id: Uuid,
  request_id request_id: Uuid,
  now now: Timestamp,
) -> job_model.Job {
  job_model.Job(
    id: job_id,
    request_id: option.Some(request_id),
    periodic_job_id: request.periodic_job_id,
    job_type: job_type,
    payload: request.payload,
    status: job_model.Pending,
    attempts: 0,
    max_attempts: request.max_attempts,
    timeout_seconds: request.timeout_seconds,
    base_backoff_seconds: job_type_policy.base_backoff_seconds,
    max_backoff_seconds: job_type_policy.max_backoff_seconds,
    run_at: request.run_at,
    started_at: option.None,
    completed_at: option.None,
    last_error: option.None,
    created_at: now,
    updated_at: now,
  )
}
