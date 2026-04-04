import gleam/option
import glot_backend/effect/auth/auth
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub fn get_user_by_email(
  email email: email_address_model.EmailAddress,
) -> program_types.Program(option.Option(user_model.User)) {
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
) -> program_types.Program(List(login_token_model.LoginToken)) {
  program_types.Impure(
    program_types.AuthEffect(auth.ListLoginTokensByUser(
      user_id: user_id,
      limit: limit,
      next: program_types.Pure,
    )),
  )
}

pub fn get_session_by_token(
  token token: String,
) -> program_types.Program(option.Option(session_model.HydratedSession)) {
  program_types.Impure(
    program_types.AuthEffect(auth.GetSessionByToken(
      token: token,
      next: program_types.Pure,
    )),
  )
}

pub fn create_user(user user: user_model.User) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.AuthEffect(auth.CreateUser(user: user, next: command_next)),
  )
}

pub fn update_user(user user: user_model.User) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.AuthEffect(auth.UpdateUser(user: user, next: command_next)),
  )
}

pub fn create_session(
  session session: session_model.Session,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.AuthEffect(auth.CreateSession(
      session: session,
      next: command_next,
    )),
  )
}

pub fn create_login_token(
  login_token login_token: login_token_model.LoginToken,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.AuthEffect(auth.CreateLoginToken(
      login_token: login_token,
      next: command_next,
    )),
  )
}

pub fn update_login_token(
  login_token login_token: login_token_model.LoginToken,
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
