import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action
import glot_backend/context
import glot_backend/crypto_helpers
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/job
import glot_backend/sql
import glot_core/rate_limit
import glot_core/uuid_helpers
import pog
import youid/uuid.{type Uuid}

pub fn new_token(length: Int) -> String {
  crypto_helpers.new_token(length)
}

pub fn system_time() -> Timestamp {
  timestamp.system_time()
}

pub fn uuid_v7(ctx: context.Context) -> Uuid {
  uuid_helpers.v7(ctx.timestamp)
}

pub fn send_email(
  _message: email_message.EmailMessage,
) -> Result(Nil, error.SendEmailError) {
  Error(error.InternalSendEmailError("send_email not implemented"))
}

pub fn get_next_job(
  ctx: context.Context,
  now: Timestamp,
  pending_status: job.Status,
  running_status: job.Status,
) -> Result(option.Option(job.Job), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(
      ctx.db,
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

pub fn count_user_actions_by_ip(
  ctx: context.Context,
  ip: option.Option(String),
  action: api_action.ApiAction,
  windows: List(rate_limit.Window),
) -> Result(List(rate_limit.WindowCount), error.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.count_user_actions_by_ip(
      ip: ip,
      action: api_action.to_db_string(action),
      windows: json.array(windows, of: rate_limit.encode_window)
        |> json.to_string(),
    ),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { window_counts_from_ip_rows(returned.rows) })
}

pub fn count_user_actions_by_user(
  ctx: context.Context,
  user_id: option.Option(Uuid),
  action: api_action.ApiAction,
  windows: List(rate_limit.Window),
) -> Result(List(rate_limit.WindowCount), error.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.count_user_actions_by_user(
      user_id: option.map(user_id, uuid.to_bit_array),
      action: api_action.to_db_string(action),
      windows: json.array(windows, of: rate_limit.encode_window)
        |> json.to_string(),
    ),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { window_counts_from_user_rows(returned.rows) })
}

pub fn insert_job(
  db: pog.Connection,
  job_value: job.Job,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_job(
      id: uuid.to_bit_array(job_value.id),
      job_type: job.job_type_to_string(job_value.job_type),
      payload: job_value.payload,
      status: job.status_to_string(job_value.status),
      attempts: job_value.attempts,
      max_attempts: job_value.max_attempts,
      timeout_seconds: job_value.timeout_seconds,
      run_at: job_value.run_at,
      started_at: job_value.started_at,
      completed_at: job_value.completed_at,
      last_error: job_value.last_error,
      created_at: job_value.created_at,
      updated_at: job_value.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn insert_user_action(
  db: pog.Connection,
  id: Uuid,
  request_id: Uuid,
  action: api_action.ApiAction,
  ip: option.Option(String),
  user_id: option.Option(Uuid),
  created_at: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_user_action(
      id: uuid.to_bit_array(id),
      request_id: uuid.to_bit_array(request_id),
      action: api_action.to_db_string(action),
      ip: ip,
      user_id: option.map(user_id, uuid.to_bit_array),
      created_at: created_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn mark_job_done(
  db: pog.Connection,
  id: Uuid,
  completed_at: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.mark_job_done(uuid.to_bit_array(id), option.Some(completed_at)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn reschedule_job(
  db: pog.Connection,
  id: Uuid,
  run_at: Timestamp,
  last_error: option.Option(String),
  updated_at: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.reschedule_job(uuid.to_bit_array(id), run_at, last_error, updated_at),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn window_counts_from_ip_rows(
  rows: List(sql.CountUserActionsByIp),
) -> Result(List(rate_limit.WindowCount), error.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use count <- result.try(window_count_from_row(first.unit, first.count))
      use counts <- result.try(window_counts_from_ip_rows(rest))
      Ok([count, ..counts])
    }
  }
}

fn window_counts_from_user_rows(
  rows: List(sql.CountUserActionsByUser),
) -> Result(List(rate_limit.WindowCount), error.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use count <- result.try(window_count_from_row(first.unit, first.count))
      use counts <- result.try(window_counts_from_user_rows(rest))
      Ok([count, ..counts])
    }
  }
}

fn window_count_from_row(
  unit: String,
  count: Int,
) -> Result(rate_limit.WindowCount, error.DbQueryError) {
  case rate_limit.unit_from_string(unit) {
    option.Some(parsed_unit) ->
      Ok(rate_limit.WindowCount(unit: parsed_unit, count: count))
    option.None ->
      Error(error.DbQueryError(
        "Invalid time unit in rate limit row: " <> unit,
      ))
  }
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
