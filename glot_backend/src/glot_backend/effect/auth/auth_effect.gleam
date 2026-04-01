import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/auth/auth
import glot_backend/effect/error
import glot_backend/effect/types
import glot_core/auth as auth_core
import glot_core/email
import glot_core/user
import youid/uuid.{type Uuid}

pub fn db_get_user_by_email(
  email email: email.Email,
) -> types.Program(option.Option(user.User)) {
  types.Impure(types.AuthEffect(auth.GetUserByEmail(email:, next: types.Pure)))
}

pub fn db_list_login_tokens_by_user(
  user_id user_id: Uuid,
  limit limit: Int,
) -> types.Program(List(auth_core.LoginToken)) {
  types.Impure(types.AuthEffect(auth.ListLoginTokensByUser(
    user_id: user_id,
    limit: limit,
    next: types.Pure,
  )))
}

pub fn db_get_session_by_token(
  token token: String,
) -> types.Program(option.Option(auth_core.Session)) {
  types.Impure(
    types.AuthEffect(auth.GetSessionByToken(token: token, next: types.Pure)),
  )
}

pub fn insert_user(
  id id: Uuid,
  email email: String,
  created_at created_at: Timestamp,
) -> types.Program(Nil) {
  types.Impure(types.AuthEffect(auth.RunCommand(
    auth.InsertUser(id:, email:, created_at:),
    command_next,
  )))
}

pub fn insert_session(
  id id: Uuid,
  user_id user_id: Uuid,
  token token: String,
  ip ip: option.Option(String),
  user_agent user_agent: option.Option(String),
  created_at created_at: Timestamp,
) -> types.Program(Nil) {
  types.Impure(types.AuthEffect(auth.RunCommand(
    auth.InsertSession(
      id: id,
      user_id: user_id,
      token: token,
      ip: ip,
      user_agent: user_agent,
      created_at: created_at,
    ),
    command_next,
  )))
}

pub fn insert_login_token(
  id id: Uuid,
  user_id user_id: Uuid,
  token token: String,
  created_at created_at: Timestamp,
  used_at used_at: option.Option(Timestamp),
) -> types.Program(Nil) {
  types.Impure(types.AuthEffect(auth.RunCommand(
    auth.InsertLoginToken(
      id: id,
      user_id: user_id,
      token: token,
      created_at: created_at,
      used_at: used_at,
    ),
    command_next,
  )))
}

pub fn update_login_token(
  user_id user_id: Uuid,
  token token: String,
  created_at created_at: Timestamp,
  used_at used_at: option.Option(Timestamp),
  id id: Uuid,
) -> types.Program(Nil) {
  types.Impure(types.AuthEffect(auth.RunCommand(
    auth.UpdateLoginToken(
      user_id: user_id,
      token: token,
      created_at: created_at,
      used_at: used_at,
      id: id,
    ),
    command_next,
  )))
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> types.Program(Nil) {
  case result {
    Ok(_) -> types.Pure(Nil)
    Error(err) -> types.Fail(error.CommandError(err))
  }
}
