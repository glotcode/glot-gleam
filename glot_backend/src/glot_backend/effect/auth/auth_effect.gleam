import gleam/option
import glot_backend/effect/auth/auth
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_core/auth as auth_core
import glot_core/email
import glot_core/session
import glot_core/user
import youid/uuid.{type Uuid}

pub fn db_get_user_by_email(
  email email: email.Email,
) -> program_types.Program(option.Option(user.User)) {
  program_types.Impure(
    program_types.AuthEffect(auth.GetUserByEmail(
      email:,
      next: program_types.Pure,
    )),
  )
}

pub fn list_login_tokens_by_user(
  user_id user_id: Uuid,
  limit limit: Int,
) -> program_types.Program(List(auth_core.LoginToken)) {
  program_types.Impure(
    program_types.AuthEffect(auth.ListLoginTokensByUser(
      user_id: user_id,
      limit: limit,
      next: program_types.Pure,
    )),
  )
}

pub fn db_get_session_by_token(
  token token: String,
) -> program_types.Program(option.Option(session.HydratedSession)) {
  program_types.Impure(
    program_types.AuthEffect(auth.GetSessionByToken(
      token: token,
      next: program_types.Pure,
    )),
  )
}

pub fn create_user(user user: user.User) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.AuthEffect(auth.CreateUser(user: user, next: command_next)),
  )
}

pub fn create_session(
  session session: session.Session,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.AuthEffect(auth.CreateSession(
      session: session,
      next: command_next,
    )),
  )
}

pub fn create_login_token(
  login_token login_token: auth_core.LoginToken,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.AuthEffect(auth.CreateLoginToken(
      login_token: login_token,
      next: command_next,
    )),
  )
}

pub fn update_login_token(
  login_token login_token: auth_core.LoginToken,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.AuthEffect(auth.UpdateLoginToken(
      login_token: login_token,
      next: command_next,
    )),
  )
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}
