import gleam/option
import gleam/result
import gleam/string
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/job/job_model
import pog

pub type JobTypePolicyHandlers {
  JobTypePolicyHandlers(
    get_job_type_policy_by_job_type: fn(job_model.JobType) ->
      Result(option.Option(job_model.JobTypePolicy), error.DbQueryError),
  )
}

pub fn new(db: pog.Connection) -> JobTypePolicyHandlers {
  JobTypePolicyHandlers(get_job_type_policy_by_job_type: fn(job_type) {
    get_job_type_policy_by_job_type(db, job_type)
  })
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
    [row] -> job_type_policy_from_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one job type policy row"))
  }
}

fn job_type_policy_from_row(
  row: sql.GetJobTypePolicyByJobType,
) -> Result(job_model.JobTypePolicy, error.DbQueryError) {
  use job_type <- result.try(
    job_model.job_type_from_string(row.job_type)
    |> result.map_error(error.DbQueryError),
  )

  Ok(job_model.JobTypePolicy(
    job_type: job_type,
    max_attempts: row.max_attempts,
    timeout_seconds: row.timeout_seconds,
    base_backoff_seconds: row.base_backoff_seconds,
    max_backoff_seconds: row.max_backoff_seconds,
    created_at: row.created_at,
    updated_at: row.updated_at,
  ))
}
