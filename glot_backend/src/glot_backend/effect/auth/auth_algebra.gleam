import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_core/pagination_model.{type CursorPagination}
import glot_core/auth/account_model
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import youid/uuid.{type Uuid}

pub type AuthEffect(next) {
  GetUserByEmail(
    email: email_address_model.EmailAddress,
    next: fn(option.Option(user_model.HydratedUser)) -> next,
  )
  GetUserById(
    id: Uuid,
    next: fn(option.Option(user_model.HydratedUser)) -> next,
  )
  ListUsers(
    pagination: CursorPagination,
    next: fn(List(user_model.HydratedUser)) -> next,
  )
  ListLoginTokensByEmail(
    email: email_address_model.EmailAddress,
    limit: Int,
    next: fn(List(login_token_model.LoginToken)) -> next,
  )
  GetSessionByToken(
    token: String,
    next: fn(option.Option(session_model.HydratedSession)) -> next,
  )
  CreateUser(
    user: user_model.User,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  CreateAccount(
    account: account_model.Account,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdateAccount(
    account: account_model.Account,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdateUser(
    user: user_model.User,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  DeleteSessionsByAccountId(
    account_id: Uuid,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  DeleteUsersByAccountId(
    account_id: Uuid,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  DeleteAccount(
    account_id: Uuid,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  CreateSession(
    session: session_model.Session,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  DeleteSession(id: Uuid, next: fn(Result(Nil, error.DbCommandError)) -> next)
  CreateLoginToken(
    login_token: login_token_model.LoginToken,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdateLoginToken(
    login_token: login_token_model.LoginToken,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  DeleteLoginTokensBefore(
    before: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: AuthEffect(a), f: fn(a) -> b) -> AuthEffect(b) {
  case effect {
    GetUserByEmail(email:, next:) ->
      GetUserByEmail(email: email, next: fn(value) { f(next(value)) })
    GetUserById(id:, next:) ->
      GetUserById(id: id, next: fn(value) { f(next(value)) })
    ListUsers(pagination:, next:) ->
      ListUsers(pagination: pagination, next: fn(value) { f(next(value)) })
    ListLoginTokensByEmail(email:, limit:, next:) ->
      ListLoginTokensByEmail(email: email, limit: limit, next: fn(value) {
        f(next(value))
      })
    GetSessionByToken(token:, next:) ->
      GetSessionByToken(token: token, next: fn(value) { f(next(value)) })
    CreateUser(user: user, next: next) ->
      CreateUser(user: user, next: fn(value) { f(next(value)) })
    CreateAccount(account: account, next: next) ->
      CreateAccount(account: account, next: fn(value) { f(next(value)) })
    UpdateAccount(account: account, next: next) ->
      UpdateAccount(account: account, next: fn(value) { f(next(value)) })
    UpdateUser(user: user, next: next) ->
      UpdateUser(user: user, next: fn(value) { f(next(value)) })
    DeleteSessionsByAccountId(account_id: account_id, next: next) ->
      DeleteSessionsByAccountId(account_id: account_id, next: fn(value) {
        f(next(value))
      })
    DeleteUsersByAccountId(account_id: account_id, next: next) ->
      DeleteUsersByAccountId(account_id: account_id, next: fn(value) {
        f(next(value))
      })
    DeleteAccount(account_id: account_id, next: next) ->
      DeleteAccount(account_id: account_id, next: fn(value) { f(next(value)) })
    CreateSession(session: session, next: next) ->
      CreateSession(session: session, next: fn(value) { f(next(value)) })
    DeleteSession(id: id, next: next) ->
      DeleteSession(id: id, next: fn(value) { f(next(value)) })
    CreateLoginToken(login_token: login_token, next: next) ->
      CreateLoginToken(login_token: login_token, next: fn(value) {
        f(next(value))
      })
    UpdateLoginToken(login_token: login_token, next: next) ->
      UpdateLoginToken(login_token: login_token, next: fn(value) {
        f(next(value))
      })
    DeleteLoginTokensBefore(before: before, next: next) ->
      DeleteLoginTokensBefore(before: before, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetUserByEmailEffectName
  GetUserByIdEffectName
  ListUsersEffectName
  ListLoginTokensByEmailEffectName
  GetSessionByTokenEffectName
  CreateUserEffectName
  CreateAccountEffectName
  UpdateAccountEffectName
  UpdateUserEffectName
  DeleteSessionsByAccountIdEffectName
  DeleteUsersByAccountIdEffectName
  DeleteAccountEffectName
  CreateSessionEffectName
  DeleteSessionEffectName
  CreateLoginTokenEffectName
  UpdateLoginTokenEffectName
  DeleteLoginTokensBeforeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetUserByEmailEffectName -> "get_user_by_email"
    GetUserByIdEffectName -> "get_user_by_id"
    ListUsersEffectName -> "list_users"
    ListLoginTokensByEmailEffectName -> "list_login_tokens_by_email"
    GetSessionByTokenEffectName -> "get_session_by_token"
    CreateUserEffectName -> "create_user"
    CreateAccountEffectName -> "create_account"
    UpdateAccountEffectName -> "update_account"
    UpdateUserEffectName -> "update_user"
    DeleteSessionsByAccountIdEffectName -> "delete_sessions_by_account_id"
    DeleteUsersByAccountIdEffectName -> "delete_users_by_account_id"
    DeleteAccountEffectName -> "delete_account"
    CreateSessionEffectName -> "create_session"
    DeleteSessionEffectName -> "delete_session"
    CreateLoginTokenEffectName -> "create_login_token"
    UpdateLoginTokenEffectName -> "update_login_token"
    DeleteLoginTokensBeforeEffectName -> "delete_login_tokens_before"
  }
}
