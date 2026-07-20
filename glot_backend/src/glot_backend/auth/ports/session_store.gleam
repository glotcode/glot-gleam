import gleam/option
import gleam/regexp
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/auth/session_model
import youid/uuid.{type Uuid}

pub type SessionStore {
  SessionStore(
    list_by_user_id: fn(Uuid, Timestamp, Timestamp) ->
      Result(List(session_model.Session), db_error.DbQueryError),
    get_by_token: fn(regexp.Regexp, String) ->
      Result(
        option.Option(session_model.HydratedSession),
        db_error.DbQueryError,
      ),
    get_by_token_for_update: fn(String) ->
      Result(option.Option(session_model.Session), db_error.DbQueryError),
    get_by_previous_token: fn(regexp.Regexp, String) ->
      Result(
        option.Option(session_model.HydratedSession),
        db_error.DbQueryError,
      ),
    get_by_previous_token_for_update: fn(String) ->
      Result(option.Option(session_model.Session), db_error.DbQueryError),
    create: fn(session_model.Session) -> Result(Nil, db_error.DbCommandError),
    update: fn(session_model.Session) -> Result(Nil, db_error.DbCommandError),
    delete: fn(Uuid) -> Result(Nil, db_error.DbCommandError),
    delete_by_account_id: fn(Uuid) -> Result(Nil, db_error.DbCommandError),
    delete_expired: fn(Timestamp, Timestamp) ->
      Result(Nil, db_error.DbCommandError),
  )
}
