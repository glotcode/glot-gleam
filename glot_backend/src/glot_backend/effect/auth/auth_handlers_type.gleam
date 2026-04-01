import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_core/auth as auth_core
import glot_core/email
import glot_core/user
import youid/uuid.{type Uuid}

pub type AuthHandlers {
  AuthHandlers(
    get_user_by_email: fn(email.Email) ->
      Result(option.Option(user.User), error.DbQueryError),
    list_login_tokens_by_user: fn(Uuid, Int) ->
      Result(List(auth_core.LoginToken), error.DbQueryError),
    get_session_by_token: fn(String) ->
      Result(option.Option(auth_core.Session), error.DbQueryError),
    insert_user: fn(Uuid, String, Timestamp) -> Result(Nil, error.DbCommandError),
    insert_session: fn(
      Uuid,
      Uuid,
      String,
      option.Option(String),
      option.Option(String),
      Timestamp,
    ) -> Result(Nil, error.DbCommandError),
    insert_login_token: fn(
      Uuid,
      Uuid,
      String,
      Timestamp,
      option.Option(Timestamp),
    ) -> Result(Nil, error.DbCommandError),
    update_login_token: fn(
      Uuid,
      String,
      Timestamp,
      option.Option(Timestamp),
      Uuid,
    ) -> Result(Nil, error.DbCommandError),
  )
}
