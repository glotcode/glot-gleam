import gleam/option
import glot_backend/effect/auth/auth_algebra
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
    program_types.DbEffect(get_user_by_email_effect(email, program_types.Pure)),
  )
}

pub fn list_login_tokens_by_user(
  user_id user_id: Uuid,
  limit limit: Int,
) -> program_types.Program(List(login_token_model.LoginToken)) {
  program_types.Impure(
    program_types.DbEffect(list_login_tokens_by_user_effect(
      user_id,
      limit,
      program_types.Pure,
    )),
  )
}

pub fn get_session_by_token(
  token token: String,
) -> program_types.Program(option.Option(session_model.HydratedSession)) {
  program_types.Impure(
    program_types.DbEffect(get_session_by_token_effect(
      token,
      program_types.Pure,
    )),
  )
}

pub fn create_user(user user: user_model.User) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_user_effect(user, command_next)),
  )
}

pub fn update_user(user user: user_model.User) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_user_effect(user, command_next)),
  )
}

pub fn create_session(
  session session: session_model.Session,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_session_effect(session, command_next)),
  )
}

pub fn create_login_token(
  login_token login_token: login_token_model.LoginToken,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_login_token_effect(login_token, command_next)),
  )
}

pub fn update_login_token(
  login_token login_token: login_token_model.LoginToken,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_login_token_effect(login_token, command_next)),
  )
}

pub fn get_user_by_email_tx(
  email email: email_address_model.EmailAddress,
) -> program_types.TransactionProgram(option.Option(user_model.User)) {
  program_types.TxImpure(get_user_by_email_effect(email, program_types.TxPure))
}

pub fn list_login_tokens_by_user_tx(
  user_id user_id: Uuid,
  limit limit: Int,
) -> program_types.TransactionProgram(List(login_token_model.LoginToken)) {
  program_types.TxImpure(list_login_tokens_by_user_effect(
    user_id,
    limit,
    program_types.TxPure,
  ))
}

pub fn get_session_by_token_tx(
  token token: String,
) -> program_types.TransactionProgram(
  option.Option(session_model.HydratedSession),
) {
  program_types.TxImpure(get_session_by_token_effect(
    token,
    program_types.TxPure,
  ))
}

pub fn create_user_tx(
  user user: user_model.User,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_user_effect(user, tx_command_next))
}

pub fn update_user_tx(
  user user: user_model.User,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_user_effect(user, tx_command_next))
}

pub fn create_session_tx(
  session session: session_model.Session,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_session_effect(session, tx_command_next))
}

pub fn create_login_token_tx(
  login_token login_token: login_token_model.LoginToken,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_login_token_effect(login_token, tx_command_next))
}

pub fn update_login_token_tx(
  login_token login_token: login_token_model.LoginToken,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_login_token_effect(login_token, tx_command_next))
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}

fn tx_command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.TransactionProgram(Nil) {
  case result {
    Ok(_) -> program_types.TxPure(Nil)
    Error(err) -> program_types.TxFail(error.CommandError(err))
  }
}

fn get_user_by_email_effect(
  email: email_address_model.EmailAddress,
  next: fn(option.Option(user_model.User)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.GetUserByEmail(email:, next: next))
}

fn list_login_tokens_by_user_effect(
  user_id: Uuid,
  limit: Int,
  next: fn(List(login_token_model.LoginToken)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.ListLoginTokensByUser(
    user_id:,
    limit:,
    next: next,
  ))
}

fn get_session_by_token_effect(
  token: String,
  next: fn(option.Option(session_model.HydratedSession)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.GetSessionByToken(token:, next: next))
}

fn create_user_effect(
  user: user_model.User,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.CreateUser(user: user, next: next))
}

fn update_user_effect(
  user: user_model.User,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.UpdateUser(user: user, next: next))
}

fn create_session_effect(
  session: session_model.Session,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.CreateSession(session:, next: next))
}

fn create_login_token_effect(
  login_token: login_token_model.LoginToken,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.CreateLoginToken(
    login_token:,
    next: next,
  ))
}

fn update_login_token_effect(
  login_token: login_token_model.LoginToken,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.UpdateLoginToken(
    login_token:,
    next: next,
  ))
}
