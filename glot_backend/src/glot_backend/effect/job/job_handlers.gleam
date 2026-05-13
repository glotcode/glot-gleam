import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/helpers/uuid_helpers
import glot_core/job/job_model
import glot_core/pagination_model
import pog
import youid/uuid

pub type JobHandlers {
  JobHandlers(
    list_jobs: fn(job_model.ListJobsFilter, pagination_model.CursorPagination) ->
      Result(List(job_model.Job), error.DbQueryError),
    summarize_jobs: fn(job_model.ListJobsFilter, Timestamp) ->
      Result(job_model.Summary, error.DbQueryError),
    get_next_job: fn(Timestamp, job_model.Status) ->
      Result(option.Option(job_model.Job), error.DbQueryError),
    get_job_by_id: fn(uuid.Uuid) ->
      Result(option.Option(job_model.Job), error.DbQueryError),
    create_job: fn(job_model.Job) -> Result(Nil, error.DbCommandError),
    update_job: fn(job_model.Job) -> Result(Nil, error.DbCommandError),
    delete_job: fn(uuid.Uuid) -> Result(Nil, error.DbCommandError),
    delete_before: fn(Timestamp, List(job_model.Status)) ->
      Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> JobHandlers {
  JobHandlers(
    list_jobs: fn(filter, pagination) { list_jobs(db, filter, pagination) },
    summarize_jobs: fn(filter, now) { summarize_jobs(db, filter, now) },
    get_next_job: fn(now, pending_status) {
      get_next_job(db, now, pending_status)
    },
    get_job_by_id: fn(id) { get_job_by_id(db, id) },
    create_job: fn(job) { create_job(db, job) },
    update_job: fn(job) { update_job(db, job) },
    delete_job: fn(id) { delete_job(db, id) },
    delete_before: fn(before, statuses) { delete_before(db, before, statuses) },
  )
}

pub fn list_jobs(
  db: pog.Connection,
  filter: job_model.ListJobsFilter,
  pagination: pagination_model.CursorPagination,
) -> Result(List(job_model.Job), error.DbQueryError) {
  let #(statuses, job_type, periodic_job_id) = filter_params(filter)

  case pagination {
    pagination_model.BeforePage(before_id, limit) ->
      decode_cursor(before_id)
      |> result.try(fn(before_uuid) {
        db_helpers.query(
          db,
          sql.list_jobs_before(
            statuses: statuses,
            job_type: job_type,
            periodic_job_id: periodic_job_id,
            before_id: option.Some(uuid.to_bit_array(before_uuid)),
            page_limit: limit,
          ),
          fn(err) { error.DbQueryError(string.inspect(err)) },
        )
        |> result.try(fn(returned) {
          returned.rows
          |> list.map(get_job_from_list_before_row)
          |> result.all
          |> result.map(list.reverse)
        })
      })
    pagination_model.InitialPage(limit)
    | pagination_model.AfterPage(_, limit) -> {
      let after_id = case pagination {
        pagination_model.AfterPage(cursor, _) ->
          decode_cursor(cursor) |> result.map(option.Some)
        pagination_model.InitialPage(_) -> Ok(option.None)
        pagination_model.BeforePage(_, _) -> Ok(option.None)
      }

      after_id
      |> result.try(fn(after_uuid) {
        db_helpers.query(
          db,
          sql.list_jobs_after(
            statuses: statuses,
            job_type: job_type,
            periodic_job_id: periodic_job_id,
            after_id: after_uuid |> option.map(uuid.to_bit_array),
            page_limit: limit,
          ),
          fn(err) { error.DbQueryError(string.inspect(err)) },
        )
        |> result.try(fn(returned) {
          returned.rows
          |> list.map(get_job_from_list_after_row)
          |> result.all
        })
      })
    }
  }
}

pub fn summarize_jobs(
  db: pog.Connection,
  filter: job_model.ListJobsFilter,
  now: Timestamp,
) -> Result(job_model.Summary, error.DbQueryError) {
  let #(statuses, job_type, periodic_job_id) = filter_params(filter)

  use returned <- result.try(
    db_helpers.query(
      db,
      sql.summarize_jobs(
        statuses: statuses,
        job_type: job_type,
        periodic_job_id: periodic_job_id,
        now: now,
      ),
      fn(err) { error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [summary] ->
      Ok(job_model.Summary(
        total_count: summary.total_count,
        pending_count: summary.pending_count,
        running_count: summary.running_count,
        failed_count: summary.failed_count,
        done_count: summary.done_count,
        overdue_count: summary.overdue_count,
      ))
    [] -> Error(error.DbQueryError("Expected one jobs summary row"))
    _ -> Error(error.DbQueryError("Expected at most one jobs summary row"))
  }
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
      periodic_job_id: j.periodic_job_id |> option.map(uuid.to_bit_array),
      job_type: job_model.job_type_to_string(j.job_type),
      payload: j.payload,
      status: job_model.status_to_string(j.status),
      attempts: j.attempts,
      max_attempts: j.max_attempts,
      timeout_seconds: j.timeout_seconds,
      base_backoff_seconds: j.base_backoff_seconds,
      max_backoff_seconds: j.max_backoff_seconds,
      run_at: j.run_at,
      started_at: j.started_at,
      lease_expires_at: j.lease_expires_at,
      completed_at: j.completed_at,
      timed_out_at: j.timed_out_at,
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
      periodic_job_id: j.periodic_job_id |> option.map(uuid.to_bit_array),
      job_type: job_model.job_type_to_string(j.job_type),
      payload: j.payload,
      status: job_model.status_to_string(j.status),
      attempts: j.attempts,
      max_attempts: j.max_attempts,
      timeout_seconds: j.timeout_seconds,
      base_backoff_seconds: j.base_backoff_seconds,
      max_backoff_seconds: j.max_backoff_seconds,
      run_at: j.run_at,
      started_at: j.started_at,
      lease_expires_at: j.lease_expires_at,
      completed_at: j.completed_at,
      timed_out_at: j.timed_out_at,
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

pub fn delete_before(
  db: pog.Connection,
  before: Timestamp,
  statuses: List(job_model.Status),
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_before(
      before: option.Some(before),
      statuses: list.map(statuses, job_model.status_to_string),
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn get_job_from_next_job_row(
  row: sql.GetNextJob,
) -> Result(job_model.Job, error.DbQueryError) {
  get_job(
    row.id,
    row.request_id,
    row.periodic_job_id,
    row.job_type,
    row.payload,
    row.status,
    row.attempts,
    row.max_attempts,
    row.timeout_seconds,
    row.base_backoff_seconds,
    row.max_backoff_seconds,
    row.run_at,
    row.started_at,
    row.lease_expires_at,
    row.completed_at,
    row.timed_out_at,
    row.last_error,
    row.created_at,
    row.updated_at,
  )
}

fn get_job_from_list_after_row(
  row: sql.ListJobsAfter,
) -> Result(job_model.Job, error.DbQueryError) {
  get_job(
    row.id,
    row.request_id,
    row.periodic_job_id,
    row.job_type,
    row.payload,
    row.status,
    row.attempts,
    row.max_attempts,
    row.timeout_seconds,
    row.base_backoff_seconds,
    row.max_backoff_seconds,
    row.run_at,
    row.started_at,
    row.lease_expires_at,
    row.completed_at,
    row.timed_out_at,
    row.last_error,
    row.created_at,
    row.updated_at,
  )
}

fn get_job_from_list_before_row(
  row: sql.ListJobsBefore,
) -> Result(job_model.Job, error.DbQueryError) {
  get_job(
    row.id,
    row.request_id,
    row.periodic_job_id,
    row.job_type,
    row.payload,
    row.status,
    row.attempts,
    row.max_attempts,
    row.timeout_seconds,
    row.base_backoff_seconds,
    row.max_backoff_seconds,
    row.run_at,
    row.started_at,
    row.lease_expires_at,
    row.completed_at,
    row.timed_out_at,
    row.last_error,
    row.created_at,
    row.updated_at,
  )
}

fn filter_params(
  filter: job_model.ListJobsFilter,
) -> #(List(String), option.Option(String), option.Option(BitArray)) {
  #(
    list.map(filter.statuses, job_model.status_to_string),
    filter.job_type,
    filter.periodic_job_id |> option.map(uuid.to_bit_array),
  )
}

fn decode_cursor(
  cursor: pagination_model.Cursor,
) -> Result(uuid.Uuid, error.DbQueryError) {
  case uuid.from_string(pagination_model.to_string(cursor)) {
    Ok(value) -> Ok(value)
    Error(_) -> Error(error.DbQueryError("Invalid jobs cursor"))
  }
}

fn get_job_from_job_by_id_row(
  row: sql.GetJobById,
) -> Result(job_model.Job, error.DbQueryError) {
  get_job(
    row.id,
    row.request_id,
    row.periodic_job_id,
    row.job_type,
    row.payload,
    row.status,
    row.attempts,
    row.max_attempts,
    row.timeout_seconds,
    row.base_backoff_seconds,
    row.max_backoff_seconds,
    row.run_at,
    row.started_at,
    row.lease_expires_at,
    row.completed_at,
    row.timed_out_at,
    row.last_error,
    row.created_at,
    row.updated_at,
  )
}

fn get_job(
  id: BitArray,
  request_id: option.Option(BitArray),
  periodic_job_id: option.Option(BitArray),
  job_type_str: String,
  payload: option.Option(String),
  status_str: String,
  attempts: Int,
  max_attempts: Int,
  timeout_seconds: Int,
  base_backoff_seconds: Int,
  max_backoff_seconds: Int,
  run_at: Timestamp,
  started_at: option.Option(Timestamp),
  lease_expires_at: option.Option(Timestamp),
  completed_at: option.Option(Timestamp),
  timed_out_at: option.Option(Timestamp),
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
    periodic_job_id: periodic_job_id |> option.map(uuid_helpers.from_bit_array),
    job_type: job_type,
    payload: payload,
    status: status,
    attempts: attempts,
    max_attempts: max_attempts,
    timeout_seconds: timeout_seconds,
    base_backoff_seconds: base_backoff_seconds,
    max_backoff_seconds: max_backoff_seconds,
    run_at: run_at,
    started_at: started_at,
    lease_expires_at: lease_expires_at,
    completed_at: completed_at,
    timed_out_at: timed_out_at,
    last_error: last_error,
    created_at: created_at,
    updated_at: updated_at,
  ))
}
