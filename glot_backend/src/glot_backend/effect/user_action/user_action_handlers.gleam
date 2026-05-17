import gleam/json
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error/db_error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/api_action
import glot_core/rate_limit
import glot_core/user_action
import youid/uuid

pub type UserActionHandlers {
  UserActionHandlers(
    count_user_actions: fn(user_action.UserActionFilter) ->
      Result(List(rate_limit.WindowCount), db_error.DbQueryError),
    create_user_action: fn(user_action.UserAction) ->
      Result(Nil, db_error.DbCommandError),
    delete_before: fn(Timestamp) -> Result(Nil, db_error.DbCommandError),
  )
}

pub fn new(db: db_helpers.Db) -> UserActionHandlers {
  UserActionHandlers(
    count_user_actions: fn(filter) { count_user_actions(db, filter) },
    create_user_action: fn(user_action) { create_user_action(db, user_action) },
    delete_before: fn(before) { delete_before(db, before) },
  )
}

pub fn count_user_actions(
  db: db_helpers.Db,
  filter: user_action.UserActionFilter,
) -> Result(List(rate_limit.WindowCount), db_error.DbQueryError) {
  case filter.count_by {
    user_action.CountByIp(ip) ->
      db_helpers.query(
        db,
        sql.count_user_actions_by_ip(
          ip: option.Some(ip),
          action: api_action.to_string(filter.action),
          windows: json.array(filter.windows, of: rate_limit.encode_window)
            |> json.to_string(),
        ),
        fn(err) { db_error.DbQueryError(string.inspect(err)) },
      )
      |> result.try(fn(returned) { window_counts_from_ip_rows(returned.rows) })
    user_action.CountByUser(user_id) ->
      db_helpers.query(
        db,
        sql.count_user_actions_by_user(
          user_id: option.Some(uuid.to_bit_array(user_id)),
          action: api_action.to_string(filter.action),
          windows: json.array(filter.windows, of: rate_limit.encode_window)
            |> json.to_string(),
        ),
        fn(err) { db_error.DbQueryError(string.inspect(err)) },
      )
      |> result.try(fn(returned) { window_counts_from_user_rows(returned.rows) })
  }
}

pub fn create_user_action(
  db: db_helpers.Db,
  user_action: user_action.UserAction,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_user_action(
      id: uuid.to_bit_array(user_action.id),
      request_id: uuid.to_bit_array(user_action.request_id),
      action: api_action.to_string(user_action.action),
      ip: user_action.ip,
      user_id: option.map(user_action.user_id, uuid.to_bit_array),
      created_at: user_action.created_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_before(
  db: db_helpers.Db,
  before: Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_user_actions_before(before), to_error)
  |> result.map(fn(_) { Nil })
}

fn window_counts_from_ip_rows(
  rows: List(sql.CountUserActionsByIp),
) -> Result(List(rate_limit.WindowCount), db_error.DbQueryError) {
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
) -> Result(List(rate_limit.WindowCount), db_error.DbQueryError) {
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
) -> Result(rate_limit.WindowCount, db_error.DbQueryError) {
  case rate_limit.unit_from_string(unit) {
    option.Some(parsed_unit) ->
      Ok(rate_limit.WindowCount(unit: parsed_unit, count: count))
    option.None ->
      Error(db_error.DbQueryError(
        "Invalid time unit in rate limit row: " <> unit,
      ))
  }
}
