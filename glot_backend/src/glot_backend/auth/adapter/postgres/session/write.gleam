import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/auth/platform_model
import glot_core/auth/session_model.{type Session}
import youid/uuid.{type Uuid}

pub fn create(
  db: db_helpers.Db,
  session: Session,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.insert_session(
      id: uuid.to_bit_array(session.id),
      user_id: uuid.to_bit_array(session.user_id),
      token: session.token,
      previous_token: session.previous_token,
      previous_token_valid_until: session.previous_token_valid_until,
      ip: session.ip,
      os_name: option.map(
        session.os_name,
        platform_model.operating_system_to_string,
      ),
      browser_name: option.map(
        session.browser_name,
        platform_model.browser_to_string,
      ),
      user_agent: session.user_agent,
      created_at: session.created_at,
      token_updated_at: session.token_updated_at,
      last_activity_at: session.last_activity_at,
    ),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update(
  db: db_helpers.Db,
  session: Session,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.update_session(
      user_id: uuid.to_bit_array(session.user_id),
      token: session.token,
      previous_token: session.previous_token,
      previous_token_valid_until: session.previous_token_valid_until,
      ip: session.ip,
      os_name: option.map(
        session.os_name,
        platform_model.operating_system_to_string,
      ),
      browser_name: option.map(
        session.browser_name,
        platform_model.browser_to_string,
      ),
      user_agent: session.user_agent,
      created_at: session.created_at,
      token_updated_at: session.token_updated_at,
      last_activity_at: session.last_activity_at,
      id: uuid.to_bit_array(session.id),
    ),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete(
  db: db_helpers.Db,
  id: Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.delete_session(uuid.to_bit_array(id)),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_by_account_id(
  db: db_helpers.Db,
  account_id: Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.delete_sessions_by_account_id(uuid.to_bit_array(account_id)),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_expired(
  db: db_helpers.Db,
  created_before: Timestamp,
  last_activity_before: Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.delete_expired_sessions(
      created_at: created_before,
      last_activity_at: last_activity_before,
    ),
    command_error,
  )
  |> result.map(fn(_) { Nil })
}

fn command_error(error) -> db_error.DbCommandError {
  db_error.DbCommandError(string.inspect(error))
}
