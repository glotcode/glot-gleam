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
