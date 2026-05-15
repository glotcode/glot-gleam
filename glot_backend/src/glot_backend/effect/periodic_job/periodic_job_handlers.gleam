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
import glot_core/periodic_job/periodic_job_model
import youid/uuid

pub type PeriodicJobHandlers {
  PeriodicJobHandlers(
    list_periodic_jobs: fn() ->
      Result(List(periodic_job_model.PeriodicJob), error.DbQueryError),
    get_next_periodic_job: fn(Timestamp) ->
      Result(option.Option(periodic_job_model.PeriodicJob), error.DbQueryError),
    get_periodic_job_by_id: fn(uuid.Uuid) ->
      Result(option.Option(periodic_job_model.PeriodicJob), error.DbQueryError),
    create_periodic_job: fn(periodic_job_model.PeriodicJob) ->
      Result(Nil, error.DbCommandError),
    update_periodic_job: fn(periodic_job_model.PeriodicJob) ->
      Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: db_helpers.Db) -> PeriodicJobHandlers {
  PeriodicJobHandlers(
    list_periodic_jobs: fn() { list_periodic_jobs(db) },
    get_next_periodic_job: fn(now) { get_next_periodic_job(db, now) },
    get_periodic_job_by_id: fn(id) { get_periodic_job_by_id(db, id) },
    create_periodic_job: fn(periodic_job) {
      create_periodic_job(db, periodic_job)
    },
    update_periodic_job: fn(periodic_job) {
      update_periodic_job(db, periodic_job)
    },
  )
}

pub fn list_periodic_jobs(
  db: db_helpers.Db,
) -> Result(List(periodic_job_model.PeriodicJob), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(db, sql.list_periodic_jobs(), fn(err) {
      error.DbQueryError(string.inspect(err))
    }),
  )

  returned.rows
  |> list.map(periodic_job_from_list_row)
  |> result.all
}

pub fn get_next_periodic_job(
  db: db_helpers.Db,
  now: Timestamp,
) -> Result(option.Option(periodic_job_model.PeriodicJob), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(db, sql.get_next_periodic_job(now), fn(err) {
      error.DbQueryError(string.inspect(err))
    }),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> periodic_job_from_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one periodic job row"))
  }
}

pub fn get_periodic_job_by_id(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(option.Option(periodic_job_model.PeriodicJob), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      db,
      sql.get_periodic_job_by_id(id: uuid.to_bit_array(id)),
      fn(err) { error.DbQueryError(string.inspect(err)) },
    ),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> periodic_job_from_get_by_id_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one periodic job row"))
  }
}

pub fn create_periodic_job(
  db: db_helpers.Db,
  periodic_job: periodic_job_model.PeriodicJob,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_periodic_job(
      id: uuid.to_bit_array(periodic_job.id),
      job_type: job_model.job_type_to_string(periodic_job.job_type),
      payload: periodic_job.payload,
      interval_seconds: periodic_job.interval_seconds,
      enabled: periodic_job.enabled,
      next_run_at: periodic_job.next_run_at,
      last_enqueued_at: periodic_job.last_enqueued_at,
      last_enqueue_error: periodic_job.last_enqueue_error,
      created_at: periodic_job.created_at,
      updated_at: periodic_job.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update_periodic_job(
  db: db_helpers.Db,
  periodic_job: periodic_job_model.PeriodicJob,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_periodic_job(
      id: uuid.to_bit_array(periodic_job.id),
      job_type: job_model.job_type_to_string(periodic_job.job_type),
      payload: periodic_job.payload,
      interval_seconds: periodic_job.interval_seconds,
      enabled: periodic_job.enabled,
      next_run_at: periodic_job.next_run_at,
      last_enqueued_at: periodic_job.last_enqueued_at,
      last_enqueue_error: periodic_job.last_enqueue_error,
      created_at: periodic_job.created_at,
      updated_at: periodic_job.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn periodic_job_from_row(
  row: sql.GetNextPeriodicJob,
) -> Result(periodic_job_model.PeriodicJob, error.DbQueryError) {
  use job_type <- result.try(
    job_model.job_type_from_string(row.job_type)
    |> result.map_error(error.DbQueryError),
  )

  Ok(periodic_job_model.PeriodicJob(
    id: uuid_helpers.from_bit_array(row.id),
    job_type: job_type,
    payload: row.payload,
    interval_seconds: row.interval_seconds,
    enabled: row.enabled,
    next_run_at: row.next_run_at,
    last_enqueued_at: row.last_enqueued_at,
    last_enqueue_error: row.last_enqueue_error,
    created_at: row.created_at,
    updated_at: row.updated_at,
  ))
}

fn periodic_job_from_list_row(
  row: sql.ListPeriodicJobs,
) -> Result(periodic_job_model.PeriodicJob, error.DbQueryError) {
  use job_type <- result.try(
    job_model.job_type_from_string(row.job_type)
    |> result.map_error(error.DbQueryError),
  )

  Ok(periodic_job_model.PeriodicJob(
    id: uuid_helpers.from_bit_array(row.id),
    job_type: job_type,
    payload: row.payload,
    interval_seconds: row.interval_seconds,
    enabled: row.enabled,
    next_run_at: row.next_run_at,
    last_enqueued_at: row.last_enqueued_at,
    last_enqueue_error: row.last_enqueue_error,
    created_at: row.created_at,
    updated_at: row.updated_at,
  ))
}

fn periodic_job_from_get_by_id_row(
  row: sql.GetPeriodicJobById,
) -> Result(periodic_job_model.PeriodicJob, error.DbQueryError) {
  use job_type <- result.try(
    job_model.job_type_from_string(row.job_type)
    |> result.map_error(error.DbQueryError),
  )

  Ok(periodic_job_model.PeriodicJob(
    id: uuid_helpers.from_bit_array(row.id),
    job_type: job_type,
    payload: row.payload,
    interval_seconds: row.interval_seconds,
    enabled: row.enabled,
    next_run_at: row.next_run_at,
    last_enqueued_at: row.last_enqueued_at,
    last_enqueue_error: row.last_enqueue_error,
    created_at: row.created_at,
    updated_at: row.updated_at,
  ))
}
