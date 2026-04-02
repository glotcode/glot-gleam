import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/job
import glot_backend/sql
import glot_core/uuid_helpers
import pog
import youid/uuid

pub type JobHandlers {
  JobHandlers(
    get_next_job: fn(Timestamp, job.Status, job.Status) ->
      Result(option.Option(job.Job), error.DbQueryError),
    insert_job: fn(job.Job) -> Result(Nil, error.DbCommandError),
    update_job: fn(job.Job) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> JobHandlers {
  JobHandlers(
    get_next_job: fn(now, pending_status, running_status) {
      get_next_job(db, now, pending_status, running_status)
    },
    insert_job: fn(job) { insert_job(db, job) },
    update_job: fn(job) { update_job(db, job) },
  )
}

pub fn get_next_job(
  db: pog.Connection,
  now: Timestamp,
  pending_status: job.Status,
  running_status: job.Status,
) -> Result(option.Option(job.Job), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_next_job(
        job.status_to_string(running_status),
        option.Some(now),
        job.status_to_string(pending_status),
      ),
      fn(err) { error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> get_job_from_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one job row"))
  }
}

pub fn insert_job(
  db: pog.Connection,
  j: job.Job,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_job(
      id: uuid.to_bit_array(j.id),
      job_type: job.job_type_to_string(j.job_type),
      payload: j.payload,
      status: job.status_to_string(j.status),
      attempts: j.attempts,
      max_attempts: j.max_attempts,
      timeout_seconds: j.timeout_seconds,
      run_at: j.run_at,
      started_at: j.started_at,
      completed_at: j.completed_at,
      last_error: j.last_error,
      created_at: j.created_at,
      updated_at: j.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update_job(
  db: pog.Connection,
  j: job.Job,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_job(
      id: uuid.to_bit_array(j.id),
      job_type: job.job_type_to_string(j.job_type),
      payload: j.payload,
      status: job.status_to_string(j.status),
      attempts: j.attempts,
      max_attempts: j.max_attempts,
      timeout_seconds: j.timeout_seconds,
      run_at: j.run_at,
      started_at: j.started_at,
      completed_at: j.completed_at,
      last_error: j.last_error,
      created_at: j.created_at,
      updated_at: j.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn get_job_from_row(row: sql.GetNextJob) -> Result(job.Job, error.DbQueryError) {
  use status <- result.try(
    job.status_from_string(row.status)
    |> result.map_error(error.DbQueryError),
  )
  use job_type <- result.try(
    job.job_type_from_string(row.job_type)
    |> result.map_error(error.DbQueryError),
  )

  Ok(job.Job(
    id: uuid_helpers.from_bit_array(row.id),
    job_type: job_type,
    payload: row.payload,
    status: status,
    attempts: row.attempts,
    max_attempts: row.max_attempts,
    timeout_seconds: row.timeout_seconds,
    run_at: row.run_at,
    started_at: row.started_at,
    completed_at: row.completed_at,
    last_error: row.last_error,
    created_at: row.created_at,
    updated_at: row.updated_at,
  ))
}
