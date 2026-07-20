import gleam/dict
import gleam/list
import gleam/option
import gleam/order
import gleam/string
import gleam/time/timestamp
import glot_core/helpers/timestamp_helpers
import glot_core/job/job_model
import glot_core/periodic_job/periodic_job_model
import support/integration/model
import support/integration/store/common
import youid/uuid

pub fn find_job(
  db: model.TestState,
  id: uuid.Uuid,
) -> option.Option(job_model.Job) {
  db.jobs
  |> dict.get(common.uuid_key(id))
  |> option.from_result()
}

pub fn find_expired_job(
  db: model.TestState,
  now: timestamp.Timestamp,
  status: job_model.Status,
) -> option.Option(job_model.Job) {
  db.jobs
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(_, job) = entry
    job
  })
  |> list.filter(fn(job) {
    job.status == status
    && case job.lease_expires_at {
      option.Some(lease_expires_at) ->
        timestamp_helpers.to_microseconds(lease_expires_at)
        <= timestamp_helpers.to_microseconds(now)
      option.None -> False
    }
  })
  |> list.sort(fn(a, b) {
    case a.lease_expires_at, b.lease_expires_at {
      option.Some(a_lease), option.Some(b_lease) ->
        case
          timestamp_helpers.to_microseconds(a_lease)
          < timestamp_helpers.to_microseconds(b_lease)
        {
          True -> order.Lt
          False ->
            case
              timestamp_helpers.to_microseconds(a_lease)
              > timestamp_helpers.to_microseconds(b_lease)
            {
              True -> order.Gt
              False ->
                case
                  timestamp_helpers.to_microseconds(a.created_at)
                  < timestamp_helpers.to_microseconds(b.created_at)
                {
                  True -> order.Lt
                  False ->
                    case
                      timestamp_helpers.to_microseconds(a.created_at)
                      > timestamp_helpers.to_microseconds(b.created_at)
                    {
                      True -> order.Gt
                      False -> order.Eq
                    }
                }
            }
        }
      _, _ -> order.Eq
    }
  })
  |> list.first
  |> option.from_result()
}

pub fn find_job_type_policy(
  db: model.TestState,
  job_type: job_model.JobType,
) -> option.Option(job_model.JobTypePolicy) {
  db.job_type_policies
  |> dict.get(job_model.job_type_to_string(job_type))
  |> option.from_result()
}

pub fn list_job_type_policies(
  db: model.TestState,
) -> List(job_model.JobTypePolicy) {
  db.job_type_policies
  |> dict.to_list
  |> list.map(fn(entry) { entry.1 })
  |> list.sort(fn(a, b) {
    string.compare(
      job_model.job_type_to_string(a.job_type),
      job_model.job_type_to_string(b.job_type),
    )
  })
}

pub fn upsert_test_job_type_policy(
  db: model.TestState,
  policy: job_model.JobTypePolicy,
) -> model.TestState {
  model.TestState(
    ..db,
    job_type_policies: dict.insert(
      db.job_type_policies,
      job_model.job_type_to_string(policy.job_type),
      policy,
    ),
  )
}

pub fn find_next_periodic_job(
  db: model.TestState,
  now: timestamp.Timestamp,
) -> option.Option(periodic_job_model.PeriodicJob) {
  list_periodic_jobs(db)
  |> list.filter(fn(periodic_job) {
    periodic_job.enabled
    && timestamp_helpers.to_microseconds(periodic_job.next_run_at)
    <= timestamp_helpers.to_microseconds(now)
  })
  |> list.sort(fn(a, b) {
    case
      timestamp_helpers.to_microseconds(a.next_run_at)
      < timestamp_helpers.to_microseconds(b.next_run_at)
    {
      True -> order.Lt
      False ->
        case
          timestamp_helpers.to_microseconds(a.next_run_at)
          > timestamp_helpers.to_microseconds(b.next_run_at)
        {
          True -> order.Gt
          False ->
            case
              timestamp_helpers.to_microseconds(a.created_at)
              < timestamp_helpers.to_microseconds(b.created_at)
            {
              True -> order.Lt
              False ->
                case
                  timestamp_helpers.to_microseconds(a.created_at)
                  > timestamp_helpers.to_microseconds(b.created_at)
                {
                  True -> order.Gt
                  False -> order.Eq
                }
            }
        }
    }
  })
  |> list.first
  |> option.from_result
}

pub fn list_periodic_jobs(
  db: model.TestState,
) -> List(periodic_job_model.PeriodicJob) {
  db.periodic_jobs
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(_, periodic_job) = entry
    periodic_job
  })
}

pub fn find_periodic_job_by_id(
  db: model.TestState,
  id: uuid.Uuid,
) -> option.Option(periodic_job_model.PeriodicJob) {
  db.periodic_jobs
  |> dict.get(common.uuid_key(id))
  |> option.from_result()
}

pub fn put_job(db: model.TestState, job: job_model.Job) -> model.TestState {
  model.TestState(
    ..db,
    jobs: dict.insert(db.jobs, common.uuid_key(job.id), job),
  )
}

pub fn delete_jobs_before_by_statuses(
  db: model.TestState,
  before: timestamp.Timestamp,
  statuses: List(job_model.Status),
) -> model.TestState {
  let before_microseconds = timestamp_helpers.to_microseconds(before)
  let kept_jobs =
    db.jobs
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, job) = entry
      let completed_at_microseconds =
        job.completed_at
        |> option.map(timestamp_helpers.to_microseconds)

      case completed_at_microseconds {
        option.Some(completed_at) ->
          case
            completed_at < before_microseconds
            && list.contains(statuses, job.status)
          {
            True -> False
            False -> True
          }
        _ -> True
      }
    })
    |> dict.from_list

  model.TestState(..db, jobs: kept_jobs)
}

pub fn put_periodic_job(
  db: model.TestState,
  periodic_job: periodic_job_model.PeriodicJob,
) -> model.TestState {
  model.TestState(
    ..db,
    periodic_jobs: dict.insert(
      db.periodic_jobs,
      common.uuid_key(periodic_job.id),
      periodic_job,
    ),
  )
}

pub fn delete_job_by_id(db: model.TestState, id: uuid.Uuid) -> model.TestState {
  model.TestState(..db, jobs: dict.delete(db.jobs, common.uuid_key(id)))
}
