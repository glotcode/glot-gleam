import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/auth/auth
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_core/auth as auth_core
import glot_core/email
import glot_core/user
import youid/uuid.{type Uuid}

pub fn db_get_user_by_email(
  email email: email.Email,
) -> effect_model.Program(option.Option(user.User)) {
  effect_model.Impure(
    effect_model.AuthEffect(auth.GetUserByEmail(email:, next: effect_model.Pure)),
  )
}

pub fn db_list_login_tokens_by_user(
  user_id user_id: Uuid,
  limit limit: Int,
) -> effect_model.Program(List(auth_core.LoginToken)) {
  effect_model.Impure(effect_model.AuthEffect(auth.ListLoginTokensByUser(
    user_id: user_id,
    limit: limit,
    next: effect_model.Pure,
  )))
}

pub fn db_get_session_by_token(
  token token: String,
) -> effect_model.Program(option.Option(auth_core.Session)) {
  effect_model.Impure(
    effect_model.AuthEffect(
      auth.GetSessionByToken(token: token, next: effect_model.Pure),
    ),
  )
}

pub fn insert_user(
  id id: Uuid,
  email email: String,
  created_at created_at: Timestamp,
) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.AuthEffect(
      auth.InsertUser(id:, email:, created_at:, next: command_next),
    ),
  )
}

pub fn insert_session(
  id id: Uuid,
  user_id user_id: Uuid,
  token token: String,
  ip ip: option.Option(String),
  user_agent user_agent: option.Option(String),
  created_at created_at: Timestamp,
) -> effect_model.Program(Nil) {
  effect_model.Impure(effect_model.AuthEffect(auth.InsertSession(
    id: id,
    user_id: user_id,
    token: token,
    ip: ip,
    user_agent: user_agent,
    created_at: created_at,
    next: command_next,
  )))
}

pub fn insert_login_token(
  id id: Uuid,
  user_id user_id: Uuid,
  token token: String,
  created_at created_at: Timestamp,
  used_at used_at: option.Option(Timestamp),
) -> effect_model.Program(Nil) {
  effect_model.Impure(effect_model.AuthEffect(auth.InsertLoginToken(
    id: id,
    user_id: user_id,
    token: token,
    created_at: created_at,
    used_at: used_at,
    next: command_next,
  )))
}

pub fn update_login_token(
  user_id user_id: Uuid,
  token token: String,
  created_at created_at: Timestamp,
  used_at used_at: option.Option(Timestamp),
  id id: Uuid,
) -> effect_model.Program(Nil) {
  effect_model.Impure(effect_model.AuthEffect(auth.UpdateLoginToken(
    user_id: user_id,
    token: token,
    created_at: created_at,
    used_at: used_at,
    id: id,
    next: command_next,
  )))
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> effect_model.Program(Nil) {
  case result {
    Ok(_) -> effect_model.Pure(Nil)
    Error(err) -> effect_model.Fail(error.CommandError(err))
  }
}
