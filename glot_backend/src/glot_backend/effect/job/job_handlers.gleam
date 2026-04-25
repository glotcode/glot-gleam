import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/helpers/uuid_helpers
import glot_core/job/job_model
import pog
import youid/uuid

pub type JobHandlers {
  JobHandlers(
    get_next_job: fn(Timestamp, job_model.Status) ->
      Result(option.Option(job_model.Job), error.DbQueryError),
    get_job_by_id: fn(uuid.Uuid) ->
      Result(option.Option(job_model.Job), error.DbQueryError),
    create_job: fn(job_model.Job) -> Result(Nil, error.DbCommandError),
    update_job: fn(job_model.Job) -> Result(Nil, error.DbCommandError),
    delete_job: fn(uuid.Uuid) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> JobHandlers {
  JobHandlers(
    get_next_job: fn(now, pending_status) {
      get_next_job(db, now, pending_status)
    },
    get_job_by_id: fn(id) { get_job_by_id(db, id) },
    create_job: fn(job) { create_job(db, job) },
    update_job: fn(job) { update_job(db, job) },
    delete_job: fn(id) { delete_job(db, id) },
  )
}

pub fn get_next_job(
  db: pog.Connection,
  now: Timestamp,
  pending_status: job_model.Status,
) -> Result(option.Option(job_model.Job), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_next_job(job_model.status_to_string(pending_status), now),
      fn(err) { error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> get_job_from_next_job_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one job row"))
  }
}

pub fn get_job_by_id(
  db: pog.Connection,
  id: uuid.Uuid,
) -> Result(option.Option(job_model.Job), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(db, sql.get_job_by_id(uuid.to_bit_array(id)), fn(err) {
      error.DbQueryError(string.inspect(err))
    }),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> get_job_from_job_by_id_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one job row"))
  }
}

pub fn create_job(
  db: pog.Connection,
  j: job_model.Job,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_job(
      id: uuid.to_bit_array(j.id),
      request_id: j.request_id |> option.map(uuid.to_bit_array),
      job_type: job_model.job_type_to_string(j.job_type),
      payload: j.payload,
      status: job_model.status_to_string(j.status),
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
  j: job_model.Job,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_job(
      id: uuid.to_bit_array(j.id),
      request_id: j.request_id |> option.map(uuid.to_bit_array),
      job_type: job_model.job_type_to_string(j.job_type),
      payload: j.payload,
      status: job_model.status_to_string(j.status),
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

pub fn delete_job(
  db: pog.Connection,
  id: uuid.Uuid,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_job(uuid.to_bit_array(id)), to_error)
  |> result.map(fn(_) { Nil })
}

fn get_job_from_next_job_row(
  row: sql.GetNextJob,
) -> Result(job_model.Job, error.DbQueryError) {
  get_job(
    row.id,
    row.request_id,
    row.job_type,
    row.payload,
    row.status,
    row.attempts,
    row.max_attempts,
    row.timeout_seconds,
    row.run_at,
    row.started_at,
    row.completed_at,
    row.last_error,
    row.created_at,
    row.updated_at,
  )
}

fn get_job_from_job_by_id_row(
  row: sql.GetJobById,
) -> Result(job_model.Job, error.DbQueryError) {
  get_job(
    row.id,
    row.request_id,
    row.job_type,
    row.payload,
    row.status,
    row.attempts,
    row.max_attempts,
    row.timeout_seconds,
    row.run_at,
    row.started_at,
    row.completed_at,
    row.last_error,
    row.created_at,
    row.updated_at,
  )
}

fn get_job(
  id: BitArray,
  request_id: option.Option(BitArray),
  job_type_str: String,
  payload: String,
  status_str: String,
  attempts: Int,
  max_attempts: Int,
  timeout_seconds: Int,
  run_at: Timestamp,
  started_at: option.Option(Timestamp),
  completed_at: option.Option(Timestamp),
  last_error: option.Option(String),
  created_at: Timestamp,
  updated_at: Timestamp,
) -> Result(job_model.Job, error.DbQueryError) {
  use status <- result.try(
    job_model.status_from_string(status_str)
    |> result.map_error(error.DbQueryError),
  )
  use job_type <- result.try(
    job_model.job_type_from_string(job_type_str)
    |> result.map_error(error.DbQueryError),
  )

  Ok(job_model.Job(
    id: uuid_helpers.from_bit_array(id),
    request_id: request_id |> option.map(uuid_helpers.from_bit_array),
    job_type: job_type,
    payload: payload,
    status: status,
    attempts: attempts,
    max_attempts: max_attempts,
    timeout_seconds: timeout_seconds,
    run_at: run_at,
    started_at: started_at,
    completed_at: completed_at,
    last_error: last_error,
    created_at: created_at,
    updated_at: updated_at,
  ))
}
