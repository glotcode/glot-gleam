import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error/db_error
import glot_core/auth/account_model
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/pagination_model.{type CursorPagination}
import youid/uuid.{type Uuid}

pub type UserListFilters {
  UserListFilters(
    email: option.Option(String),
    username: option.Option(String),
    id: option.Option(Uuid),
    role: option.Option(user_model.UserRole),
    account_state: option.Option(account_model.AccountState),
    account_tier: option.Option(account_model.AccountTier),
  )
}

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
    filters: UserListFilters,
    next: fn(List(user_model.HydratedUser)) -> next,
  )
  ListLoginTokensByEmail(
    email: email_address_model.EmailAddress,
    limit: Int,
    next: fn(List(login_token_model.LoginToken)) -> next,
  )
  GetPasskeyCredentialByCredentialId(
    credential_id: BitArray,
    next: fn(option.Option(passkey_credential_model.PasskeyCredential)) -> next,
  )
  ListPasskeyCredentialsByUserId(
    user_id: Uuid,
    next: fn(List(passkey_credential_model.PasskeyCredential)) -> next,
  )
  GetPasskeyChallengeById(
    id: Uuid,
    next: fn(option.Option(passkey_challenge_model.PasskeyChallenge)) -> next,
  )
  GetSessionByToken(
    token: String,
    next: fn(option.Option(session_model.HydratedSession)) -> next,
  )
  GetSessionByTokenForUpdate(
    token: String,
    next: fn(option.Option(session_model.Session)) -> next,
  )
  GetSessionByPreviousToken(
    token: String,
    next: fn(option.Option(session_model.HydratedSession)) -> next,
  )
  GetSessionByPreviousTokenForUpdate(
    token: String,
    next: fn(option.Option(session_model.Session)) -> next,
  )
  CreateUser(
    user: user_model.User,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  CreateAccount(
    account: account_model.Account,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  UpdateAccount(
    account: account_model.Account,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  UpdateUser(
    user: user_model.User,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeleteSessionsByAccountId(
    account_id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeleteUsersByAccountId(
    account_id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeleteAccount(
    account_id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  CreateSession(
    session: session_model.Session,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  UpdateSession(
    session: session_model.Session,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeleteSession(
    id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  CreateLoginToken(
    login_token: login_token_model.LoginToken,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  CreatePasskeyCredential(
    passkey_credential: passkey_credential_model.PasskeyCredential,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  CreatePasskeyChallenge(
    passkey_challenge: passkey_challenge_model.PasskeyChallenge,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  UpdateLoginToken(
    login_token: login_token_model.LoginToken,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  UpdatePasskeyCredential(
    passkey_credential: passkey_credential_model.PasskeyCredential,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeleteLoginTokensBefore(
    before: Timestamp,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeletePasskeyChallenge(
    id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub fn map(effect: AuthEffect(a), f: fn(a) -> b) -> AuthEffect(b) {
  case effect {
    GetUserByEmail(email:, next:) ->
      GetUserByEmail(email: email, next: fn(value) { f(next(value)) })
    GetUserById(id:, next:) ->
      GetUserById(id: id, next: fn(value) { f(next(value)) })
    ListUsers(pagination:, filters:, next:) ->
      ListUsers(pagination: pagination, filters: filters, next: fn(value) {
        f(next(value))
      })
    ListLoginTokensByEmail(email:, limit:, next:) ->
      ListLoginTokensByEmail(email: email, limit: limit, next: fn(value) {
        f(next(value))
      })
    GetPasskeyCredentialByCredentialId(credential_id:, next:) ->
      GetPasskeyCredentialByCredentialId(
        credential_id: credential_id,
        next: fn(value) { f(next(value)) },
      )
    ListPasskeyCredentialsByUserId(user_id:, next:) ->
      ListPasskeyCredentialsByUserId(user_id: user_id, next: fn(value) {
        f(next(value))
      })
    GetPasskeyChallengeById(id:, next:) ->
      GetPasskeyChallengeById(id: id, next: fn(value) { f(next(value)) })
    GetSessionByToken(token:, next:) ->
      GetSessionByToken(token: token, next: fn(value) { f(next(value)) })
    GetSessionByTokenForUpdate(token:, next:) ->
      GetSessionByTokenForUpdate(token: token, next: fn(value) {
        f(next(value))
      })
    GetSessionByPreviousToken(token:, next:) ->
      GetSessionByPreviousToken(token: token, next: fn(value) { f(next(value)) })
    GetSessionByPreviousTokenForUpdate(token:, next:) ->
      GetSessionByPreviousTokenForUpdate(token: token, next: fn(value) {
        f(next(value))
      })
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
    UpdateSession(session:, next:) ->
      UpdateSession(session: session, next: fn(value) { f(next(value)) })
    DeleteSession(id: id, next: next) ->
      DeleteSession(id: id, next: fn(value) { f(next(value)) })
    CreateLoginToken(login_token: login_token, next: next) ->
      CreateLoginToken(login_token: login_token, next: fn(value) {
        f(next(value))
      })
    CreatePasskeyCredential(passkey_credential: passkey_credential, next: next) ->
      CreatePasskeyCredential(
        passkey_credential: passkey_credential,
        next: fn(value) { f(next(value)) },
      )
    CreatePasskeyChallenge(passkey_challenge: passkey_challenge, next: next) ->
      CreatePasskeyChallenge(
        passkey_challenge: passkey_challenge,
        next: fn(value) { f(next(value)) },
      )
    UpdateLoginToken(login_token: login_token, next: next) ->
      UpdateLoginToken(login_token: login_token, next: fn(value) {
        f(next(value))
      })
    UpdatePasskeyCredential(passkey_credential: passkey_credential, next: next) ->
      UpdatePasskeyCredential(
        passkey_credential: passkey_credential,
        next: fn(value) { f(next(value)) },
      )
    DeleteLoginTokensBefore(before: before, next: next) ->
      DeleteLoginTokensBefore(before: before, next: fn(value) { f(next(value)) })
    DeletePasskeyChallenge(id: id, next: next) ->
      DeletePasskeyChallenge(id: id, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetUserByEmailEffectName
  GetUserByIdEffectName
  ListUsersEffectName
  ListLoginTokensByEmailEffectName
  GetPasskeyCredentialByCredentialIdEffectName
  ListPasskeyCredentialsByUserIdEffectName
  GetPasskeyChallengeByIdEffectName
  GetSessionByTokenEffectName
  GetSessionByTokenForUpdateEffectName
  GetSessionByPreviousTokenEffectName
  GetSessionByPreviousTokenForUpdateEffectName
  CreateUserEffectName
  CreateAccountEffectName
  UpdateAccountEffectName
  UpdateUserEffectName
  DeleteSessionsByAccountIdEffectName
  DeleteUsersByAccountIdEffectName
  DeleteAccountEffectName
  CreateSessionEffectName
  UpdateSessionEffectName
  DeleteSessionEffectName
  CreateLoginTokenEffectName
  CreatePasskeyCredentialEffectName
  CreatePasskeyChallengeEffectName
  UpdateLoginTokenEffectName
  UpdatePasskeyCredentialEffectName
  DeleteLoginTokensBeforeEffectName
  DeletePasskeyChallengeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetUserByEmailEffectName -> "get_user_by_email"
    GetUserByIdEffectName -> "get_user_by_id"
    ListUsersEffectName -> "list_users"
    ListLoginTokensByEmailEffectName -> "list_login_tokens_by_email"
    GetPasskeyCredentialByCredentialIdEffectName ->
      "get_passkey_credential_by_credential_id"
    ListPasskeyCredentialsByUserIdEffectName ->
      "list_passkey_credentials_by_user_id"
    GetPasskeyChallengeByIdEffectName -> "get_passkey_challenge_by_id"
    GetSessionByTokenEffectName -> "get_session_by_token"
    GetSessionByTokenForUpdateEffectName -> "get_session_by_token_for_update"
    GetSessionByPreviousTokenEffectName -> "get_session_by_previous_token"
    GetSessionByPreviousTokenForUpdateEffectName ->
      "get_session_by_previous_token_for_update"
    CreateUserEffectName -> "create_user"
    CreateAccountEffectName -> "create_account"
    UpdateAccountEffectName -> "update_account"
    UpdateUserEffectName -> "update_user"
    DeleteSessionsByAccountIdEffectName -> "delete_sessions_by_account_id"
    DeleteUsersByAccountIdEffectName -> "delete_users_by_account_id"
    DeleteAccountEffectName -> "delete_account"
    CreateSessionEffectName -> "create_session"
    UpdateSessionEffectName -> "update_session"
    DeleteSessionEffectName -> "delete_session"
    CreateLoginTokenEffectName -> "create_login_token"
    CreatePasskeyCredentialEffectName -> "create_passkey_credential"
    CreatePasskeyChallengeEffectName -> "create_passkey_challenge"
    UpdateLoginTokenEffectName -> "update_login_token"
    UpdatePasskeyCredentialEffectName -> "update_passkey_credential"
    DeleteLoginTokensBeforeEffectName -> "delete_login_tokens_before"
    DeletePasskeyChallengeEffectName -> "delete_passkey_challenge"
  }
}
