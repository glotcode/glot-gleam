import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/error
import glot_backend/effect/error/resource_error
import glot_backend/effect/periodic_job/periodic_job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/periodic_job_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/periodic_job/periodic_job_model
import glot_core/validation_error

pub fn update_periodic_job(
  ctx: context.Context,
  request: periodic_job_dto.UpdatePeriodicJobRequest,
) -> program_types.Program(periodic_job_dto.UpdatePeriodicJobResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpdateAdminPeriodicJobAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use _ <- program.and_then(validate_request(request))
  use periodic_job <- program.and_then(
    periodic_job_effect.get_periodic_job_by_id(request.id)
    |> program.require(error.resource(resource_error.PeriodicJobNotFound)),
  )

  let updated_periodic_job =
    periodic_job_model.PeriodicJob(
      ..periodic_job,
      payload: request.payload,
      interval_seconds: request.interval_seconds,
      enabled: request.enabled,
      next_run_at: request.next_run_at,
      updated_at: ctx.timestamp,
    )

  use _ <- program.and_then(periodic_job_effect.update_periodic_job(
    updated_periodic_job,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(periodic_job_dto.from_updated_periodic_job(
    updated_periodic_job,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(periodic_job_dto.UpdatePeriodicJobRequest) {
  program.decode_dynamic(data, periodic_job_dto.update_request_decoder())
}

fn validate_request(
  request: periodic_job_dto.UpdatePeriodicJobRequest,
) -> program_types.Program(Nil) {
  case request.interval_seconds <= 0 {
    True ->
      program.fail(
        error.validation(validation_error.MustBeGreaterThan(
          "interval_seconds",
          0,
        )),
      )
    False -> program.succeed(Nil)
  }
}
