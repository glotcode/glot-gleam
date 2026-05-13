import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/job/job_model
import pog

pub type JobTypePolicyHandlers {
  JobTypePolicyHandlers(
    list_job_type_policies: fn() ->
      Result(List(job_model.JobTypePolicy), error.DbQueryError),
    get_job_type_policy_by_job_type: fn(job_model.JobType) ->
      Result(option.Option(job_model.JobTypePolicy), error.DbQueryError),
    upsert_job_type_policy: fn(job_model.JobTypePolicy, Timestamp) ->
      Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> JobTypePolicyHandlers {
  JobTypePolicyHandlers(
    list_job_type_policies: fn() { list_job_type_policies(db) },
    get_job_type_policy_by_job_type: fn(job_type) {
      get_job_type_policy_by_job_type(db, job_type)
    },
    upsert_job_type_policy: fn(policy, now) {
      upsert_job_type_policy(db, policy, now)
    },
  )
}

pub fn list_job_type_policies(
  db: pog.Connection,
) -> Result(List(job_model.JobTypePolicy), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(db, sql.list_job_type_policies(), fn(err) {
      error.DbQueryError(string.inspect(err))
    }),
  )

  returned.rows
  |> list.map(job_type_policy_from_list_row)
  |> result.all
}

pub fn get_job_type_policy_by_job_type(
  db: pog.Connection,
  job_type: job_model.JobType,
) -> Result(option.Option(job_model.JobTypePolicy), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_job_type_policy_by_job_type(
        job_type: job_model.job_type_to_string(job_type),
      ),
      fn(err) { error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> job_type_policy_from_get_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one job type policy row"))
  }
}

pub fn upsert_job_type_policy(
  db: pog.Connection,
  policy: job_model.JobTypePolicy,
  now: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.upsert_job_type_policy(
      job_type: job_model.job_type_to_string(policy.job_type),
      max_attempts: policy.max_attempts,
      timeout_seconds: policy.timeout_seconds,
      base_backoff_seconds: policy.base_backoff_seconds,
      max_backoff_seconds: policy.max_backoff_seconds,
      created_at: now,
    ),
    fn(err) { error.DbCommandError(string.inspect(err)) },
  )
  |> result.map(fn(_) { Nil })
}

fn job_type_policy_from_row(
  job_type: String,
  max_attempts: Int,
  timeout_seconds: Int,
  base_backoff_seconds: Int,
  max_backoff_seconds: Int,
  created_at: Timestamp,
  updated_at: Timestamp,
) -> Result(job_model.JobTypePolicy, error.DbQueryError) {
  use job_type <- result.try(
    job_model.job_type_from_string(job_type)
    |> result.map_error(error.DbQueryError),
  )

  Ok(job_model.JobTypePolicy(
    job_type: job_type,
    max_attempts: max_attempts,
    timeout_seconds: timeout_seconds,
    base_backoff_seconds: base_backoff_seconds,
    max_backoff_seconds: max_backoff_seconds,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn job_type_policy_from_list_row(
  row: sql.ListJobTypePolicies,
) -> Result(job_model.JobTypePolicy, error.DbQueryError) {
  job_type_policy_from_row(
    row.job_type,
    row.max_attempts,
    row.timeout_seconds,
    row.base_backoff_seconds,
    row.max_backoff_seconds,
    row.created_at,
    row.updated_at,
  )
}

fn job_type_policy_from_get_row(
  row: sql.GetJobTypePolicyByJobType,
) -> Result(job_model.JobTypePolicy, error.DbQueryError) {
  job_type_policy_from_row(
    row.job_type,
    row.max_attempts,
    row.timeout_seconds,
    row.base_backoff_seconds,
    row.max_backoff_seconds,
    row.created_at,
    row.updated_at,
  )
}
