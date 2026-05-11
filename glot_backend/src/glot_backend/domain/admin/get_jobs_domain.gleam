import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/job_dto
import glot_core/api_action
import glot_core/job/job_model
import glot_core/pagination_model
import youid/uuid

pub fn get_jobs(
  ctx: context.Context,
  request: job_dto.ListJobsRequest,
) -> program_types.Program(job_dto.ListJobsResponse) {
  let pagination = request.pagination
  use _ <- program.and_then(
    pagination_model.validate(pagination, 100)
    |> result.map_error(error.ValidationError)
    |> program.from_result,
  )
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.GetAdminJobsAction,
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))

  let filter = request_to_filter(request)

  use jobs <- program.and_then(job_effect.list_jobs(
    filter: filter,
    pagination: pagination_model.increment_limit(pagination),
  ))
  use summary <- program.and_then(job_effect.summarize_jobs(
    filter,
    ctx.timestamp,
  ))

  let page =
    pagination_model.paginate(jobs, pagination, fn(job) {
      pagination_model.from_string(uuid.to_string(job.id))
    })

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(job_dto.from_jobs(
    summary: summary,
    page: page,
    now: ctx.timestamp,
  ))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(job_dto.ListJobsRequest) {
  program.decode_dynamic(data, job_dto.list_request_decoder())
}

fn request_to_filter(
  request: job_dto.ListJobsRequest,
) -> job_model.ListJobsFilter {
  job_model.new_list_filter()
  |> job_model.with_statuses(statuses_for_filter(request.status_filter))
  |> job_model.with_job_type(request.job_type_filter)
  |> job_model.with_periodic_job_id(request.periodic_job_id)
}

fn statuses_for_filter(filter: job_dto.StatusFilter) -> List(job_model.Status) {
  case filter {
    job_dto.AllStatuses -> []
    job_dto.PendingStatus -> [job_model.Pending]
    job_dto.RunningStatus -> [job_model.Running]
    job_dto.FailedStatus -> [job_model.Failed]
    job_dto.DoneStatus -> [job_model.Done]
  }
}
