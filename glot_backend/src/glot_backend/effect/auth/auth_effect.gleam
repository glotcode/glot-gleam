import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_core/auth/account_model
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/pagination_model.{type CursorPagination}
import youid/uuid.{type Uuid}

pub fn get_user_by_email(
  email email: email_address_model.EmailAddress,
) -> program_types.Program(option.Option(user_model.HydratedUser)) {
  program_types.Impure(
    program_types.DbEffect(get_user_by_email_effect(email, program_types.Pure)),
  )
}

pub fn get_user_by_id(
  id id: Uuid,
) -> program_types.Program(option.Option(user_model.HydratedUser)) {
  program_types.Impure(
    program_types.DbEffect(get_user_by_id_effect(id, program_types.Pure)),
  )
}

pub fn list_users(
  pagination pagination: CursorPagination,
) -> program_types.Program(List(user_model.HydratedUser)) {
  program_types.Impure(
    program_types.DbEffect(list_users_effect(pagination, program_types.Pure)),
  )
}

pub fn list_login_tokens_by_email(
  email email: email_address_model.EmailAddress,
  limit limit: Int,
) -> program_types.Program(List(login_token_model.LoginToken)) {
  program_types.Impure(
    program_types.DbEffect(list_login_tokens_by_email_effect(
      email,
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

pub fn create_account(
  account account: account_model.Account,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_account_effect(account, command_next)),
  )
}

pub fn update_account(
  account account: account_model.Account,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_account_effect(account, command_next)),
  )
}

pub fn update_user(user user: user_model.User) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_user_effect(user, command_next)),
  )
}

pub fn delete_sessions_by_account_id(id id: Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_sessions_by_account_id_effect(
      id,
      command_next,
    )),
  )
}

pub fn delete_users_by_account_id(id id: Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_users_by_account_id_effect(id, command_next)),
  )
}

pub fn delete_account(id id: Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_account_effect(id, command_next)),
  )
}

pub fn create_session(
  session session: session_model.Session,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_session_effect(session, command_next)),
  )
}

pub fn delete_session(id id: Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_session_effect(id, command_next)),
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

pub fn delete_login_tokens_before(
  before before: Timestamp,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_login_tokens_before_effect(
      before,
      command_next,
    )),
  )
}

pub fn get_user_by_email_tx(
  email email: email_address_model.EmailAddress,
) -> program_types.TransactionProgram(option.Option(user_model.HydratedUser)) {
  program_types.TxImpure(get_user_by_email_effect(email, program_types.TxPure))
}

pub fn get_user_by_id_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(option.Option(user_model.HydratedUser)) {
  program_types.TxImpure(get_user_by_id_effect(id, program_types.TxPure))
}

pub fn list_users_tx(
  pagination pagination: CursorPagination,
) -> program_types.TransactionProgram(List(user_model.HydratedUser)) {
  program_types.TxImpure(list_users_effect(pagination, program_types.TxPure))
}

pub fn list_login_tokens_by_email_tx(
  email email: email_address_model.EmailAddress,
  limit limit: Int,
) -> program_types.TransactionProgram(List(login_token_model.LoginToken)) {
  program_types.TxImpure(list_login_tokens_by_email_effect(
    email,
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

pub fn create_account_tx(
  account account: account_model.Account,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_account_effect(account, tx_command_next))
}

pub fn update_account_tx(
  account account: account_model.Account,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_account_effect(account, tx_command_next))
}

pub fn update_user_tx(
  user user: user_model.User,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_user_effect(user, tx_command_next))
}

pub fn delete_sessions_by_account_id_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_sessions_by_account_id_effect(
    id,
    tx_command_next,
  ))
}

pub fn delete_users_by_account_id_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_users_by_account_id_effect(id, tx_command_next))
}

pub fn delete_account_tx(id id: Uuid) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_account_effect(id, tx_command_next))
}

pub fn create_session_tx(
  session session: session_model.Session,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_session_effect(session, tx_command_next))
}

pub fn delete_session_tx(id id: Uuid) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_session_effect(id, tx_command_next))
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

pub fn delete_login_tokens_before_tx(
  before before: Timestamp,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_login_tokens_before_effect(
    before,
    tx_command_next,
  ))
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
  next: fn(option.Option(user_model.HydratedUser)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.GetUserByEmail(email:, next: next))
}

fn get_user_by_id_effect(
  id: Uuid,
  next: fn(option.Option(user_model.HydratedUser)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.GetUserById(id:, next: next))
}

fn list_users_effect(
  pagination: CursorPagination,
  next: fn(List(user_model.HydratedUser)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.ListUsers(
    pagination: pagination,
    next: next,
  ))
}

fn list_login_tokens_by_email_effect(
  email: email_address_model.EmailAddress,
  limit: Int,
  next: fn(List(login_token_model.LoginToken)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.ListLoginTokensByEmail(
    email:,
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

fn create_account_effect(
  account: account_model.Account,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.CreateAccount(account:, next: next))
}

fn update_account_effect(
  account: account_model.Account,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.UpdateAccount(account:, next: next))
}

fn update_user_effect(
  user: user_model.User,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.UpdateUser(user: user, next: next))
}

fn delete_sessions_by_account_id_effect(
  id: Uuid,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.DeleteSessionsByAccountId(
    account_id: id,
    next: next,
  ))
}

fn delete_users_by_account_id_effect(
  id: Uuid,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.DeleteUsersByAccountId(
    account_id: id,
    next: next,
  ))
}

fn delete_account_effect(
  id: Uuid,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.DeleteAccount(
    account_id: id,
    next: next,
  ))
}

fn create_session_effect(
  session: session_model.Session,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.CreateSession(session:, next: next))
}

fn delete_session_effect(
  id: Uuid,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.DeleteSession(id:, next: next))
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

fn delete_login_tokens_before_effect(
  before: Timestamp,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AuthEffect(auth_algebra.DeleteLoginTokensBefore(
    before: before,
    next: next,
  ))
}
