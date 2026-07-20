import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/auth/adapter/postgres/session/row
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/auth/session_model
import youid/uuid.{type Uuid}

pub fn list_by_user_id(
  db: db_helpers.Db,
  user_id: Uuid,
  created_since: Timestamp,
  last_activity_since: Timestamp,
) -> Result(List(session_model.Session), db_error.DbQueryError) {
  db_helpers.query(
    db,
    sql.list_sessions_by_user_id(
      user_id: uuid.to_bit_array(user_id),
      created_at: created_since,
      last_activity_at: last_activity_since,
    ),
    query_error,
  )
  |> result.try(fn(returned) { row.identities_from_list_rows(returned.rows) })
}

pub fn get_by_token(
  db: db_helpers.Db,
  is_email: regexp.Regexp,
  token: String,
) -> Result(option.Option(session_model.HydratedSession), db_error.DbQueryError) {
  db_helpers.query(db, sql.get_session_by_token(token), query_error)
  |> result.try(fn(returned) {
    row.hydrated_from_token_rows(is_email, returned.rows)
  })
}

pub fn get_by_token_for_update(
  db: db_helpers.Db,
  token: String,
) -> Result(option.Option(session_model.Session), db_error.DbQueryError) {
  db_helpers.query(db, sql.get_session_by_token_for_update(token), query_error)
  |> result.try(fn(returned) {
    row.identity_from_token_for_update_rows(returned.rows)
  })
}

pub fn get_by_previous_token(
  db: db_helpers.Db,
  is_email: regexp.Regexp,
  token: String,
) -> Result(option.Option(session_model.HydratedSession), db_error.DbQueryError) {
  db_helpers.query(
    db,
    sql.get_session_by_previous_token(option.Some(token)),
    query_error,
  )
  |> result.try(fn(returned) {
    row.hydrated_from_previous_token_rows(is_email, returned.rows)
  })
}

pub fn get_by_previous_token_for_update(
  db: db_helpers.Db,
  token: String,
) -> Result(option.Option(session_model.Session), db_error.DbQueryError) {
  db_helpers.query(
    db,
    sql.get_session_by_previous_token_for_update(option.Some(token)),
    query_error,
  )
  |> result.try(fn(returned) {
    row.identity_from_previous_token_for_update_rows(returned.rows)
  })
}

fn query_error(error) -> db_error.DbQueryError {
  db_error.DbQueryError(string.inspect(error))
}
