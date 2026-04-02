import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/api_action
import glot_backend/crypto_helpers
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/sql
import glot_core/rate_limit
import glot_core/user_action
import glot_core/uuid_helpers
import pog
import youid/uuid.{type Uuid}

pub type CoreHandlers {
  CoreHandlers(
    new_token: fn(Int) -> String,
    system_time: fn() -> Timestamp,
    uuid_v7: fn(Timestamp) -> Uuid,
    send_email: fn(email_message.EmailMessage) ->
      Result(Nil, error.SendEmailError),
    count_user_actions: fn(user_action.UserActionFilter) ->
      Result(List(rate_limit.WindowCount), error.DbQueryError),
    insert_user_action: fn(user_action.UserAction) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> CoreHandlers {
  CoreHandlers(
    new_token: new_token,
    system_time: system_time,
    uuid_v7: uuid_v7,
    send_email: send_email,
    count_user_actions: fn(filter) {
      count_user_actions(db, filter)
    },
    insert_user_action: fn(user_action) {
      insert_user_action(db, user_action)
    },
  )
}

pub fn new_token(length: Int) -> String {
  crypto_helpers.new_token(length)
}

pub fn system_time() -> Timestamp {
  timestamp.system_time()
}

pub fn uuid_v7(now: Timestamp) -> Uuid {
  uuid_helpers.v7(now)
}

pub fn send_email(
  _message: email_message.EmailMessage,
) -> Result(Nil, error.SendEmailError) {
  Error(error.InternalSendEmailError("send_email not implemented"))
}

pub fn count_user_actions(
  db: pog.Connection,
  filter: user_action.UserActionFilter,
) -> Result(List(rate_limit.WindowCount), error.DbQueryError) {
  case filter.count_by {
    user_action.CountByIp(ip) ->
      db_helpers.query(
        db,
        sql.count_user_actions_by_ip(
          ip: option.Some(ip),
          action: api_action.to_db_string(filter.action),
          windows: json.array(filter.windows, of: rate_limit.encode_window)
            |> json.to_string(),
        ),
        fn(err) { error.DbQueryError(string.inspect(err)) },
      )
      |> result.try(fn(returned) { window_counts_from_ip_rows(returned.rows) })
    user_action.CountByUser(user_id) ->
      db_helpers.query(
        db,
        sql.count_user_actions_by_user(
          user_id: option.Some(uuid.to_bit_array(user_id)),
          action: api_action.to_db_string(filter.action),
          windows: json.array(filter.windows, of: rate_limit.encode_window)
            |> json.to_string(),
        ),
        fn(err) { error.DbQueryError(string.inspect(err)) },
      )
      |> result.try(fn(returned) { window_counts_from_user_rows(returned.rows) })
  }
}

pub fn insert_user_action(
  db: pog.Connection,
  user_action: user_action.UserAction,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_user_action(
      id: uuid.to_bit_array(user_action.id),
      request_id: uuid.to_bit_array(user_action.request_id),
      action: api_action.to_db_string(user_action.action),
      ip: user_action.ip,
      user_id: option.map(user_action.user_id, uuid.to_bit_array),
      created_at: user_action.created_at,
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
