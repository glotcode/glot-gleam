import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/job/job_model.{type Job, type Status}
import youid/uuid.{type Uuid}

pub fn create(
  db: db_helpers.Db,
  job: Job,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.insert_job(
      id: uuid.to_bit_array(job.id),
      request_id: job.request_id |> option.map(uuid.to_bit_array),
      periodic_job_id: job.periodic_job_id |> option.map(uuid.to_bit_array),
      job_type: job_model.job_type_to_string(job.job_type),
      payload: job.payload,
      status: job_model.status_to_string(job.status),
      attempts: job.attempts,
      max_attempts: job.max_attempts,
      timeout_seconds: job.timeout_seconds,
      base_backoff_seconds: job.base_backoff_seconds,
      max_backoff_seconds: job.max_backoff_seconds,
      run_at: job.run_at,
      started_at: job.started_at,
      lease_expires_at: job.lease_expires_at,
      completed_at: job.completed_at,
      timed_out_at: job.timed_out_at,
      last_error: job.last_error,
      created_at: job.created_at,
      updated_at: job.updated_at,
    ),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update(
  db: db_helpers.Db,
  job: Job,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.update_job(
      id: uuid.to_bit_array(job.id),
      request_id: job.request_id |> option.map(uuid.to_bit_array),
      periodic_job_id: job.periodic_job_id |> option.map(uuid.to_bit_array),
      job_type: job_model.job_type_to_string(job.job_type),
      payload: job.payload,
      status: job_model.status_to_string(job.status),
      attempts: job.attempts,
      max_attempts: job.max_attempts,
      timeout_seconds: job.timeout_seconds,
      base_backoff_seconds: job.base_backoff_seconds,
      max_backoff_seconds: job.max_backoff_seconds,
      run_at: job.run_at,
      started_at: job.started_at,
      lease_expires_at: job.lease_expires_at,
      completed_at: job.completed_at,
      timed_out_at: job.timed_out_at,
      last_error: job.last_error,
      created_at: job.created_at,
      updated_at: job.updated_at,
    ),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete(
  db: db_helpers.Db,
  id: Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(db, sql.delete_job(uuid.to_bit_array(id)), command_error)
  |> result.map(fn(_) { Nil })
}

pub fn delete_before(
  db: db_helpers.Db,
  before: Timestamp,
  statuses: List(Status),
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.delete_before(
      before: option.Some(before),
      statuses: list.map(statuses, job_model.status_to_string),
    ),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

fn command_error(error) -> db_error.DbCommandError {
  db_error.DbCommandError(string.inspect(error))
}
