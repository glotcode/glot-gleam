import gleam/option
import glot_backend/effect/error
import glot_core/auth/login_token_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/session
import youid/uuid.{type Uuid}

pub type AuthEffect(next) {
  GetUserByEmail(
    email: email_address_model.EmailAddress,
    next: fn(option.Option(user_model.User)) -> next,
  )
  ListLoginTokensByUser(
    user_id: Uuid,
    limit: Int,
    next: fn(List(login_token_model.LoginToken)) -> next,
  )
  GetSessionByToken(
    token: String,
    next: fn(option.Option(session.HydratedSession)) -> next,
  )
  CreateUser(
    user: user_model.User,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  CreateSession(
    session: session.Session,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  CreateLoginToken(
    login_token: login_token_model.LoginToken,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdateLoginToken(
    login_token: login_token_model.LoginToken,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: AuthEffect(a), f: fn(a) -> b) -> AuthEffect(b) {
  case effect {
    GetUserByEmail(email:, next:) ->
      GetUserByEmail(email: email, next: fn(value) { f(next(value)) })
    ListLoginTokensByUser(user_id:, limit:, next:) ->
      ListLoginTokensByUser(user_id: user_id, limit: limit, next: fn(value) {
        f(next(value))
      })
    GetSessionByToken(token:, next:) ->
      GetSessionByToken(token: token, next: fn(value) { f(next(value)) })
    CreateUser(user: user, next: next) ->
      CreateUser(user: user, next: fn(value) { f(next(value)) })
    CreateSession(session: session, next: next) ->
      CreateSession(
        session: session,
        next: fn(value) { f(next(value)) },
      )
    CreateLoginToken(login_token: login_token, next: next) ->
      CreateLoginToken(
        login_token: login_token,
        next: fn(value) { f(next(value)) },
      )
    UpdateLoginToken(login_token: login_token, next: next) ->
      UpdateLoginToken(
        login_token: login_token,
        next: fn(value) { f(next(value)) },
      )
  }
}

pub type EffectName {
  GetUserByEmailEffectName
  ListLoginTokensByUserEffectName
  GetSessionByTokenEffectName
  CreateUserEffectName
  CreateSessionEffectName
  CreateLoginTokenEffectName
  UpdateLoginTokenEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetUserByEmailEffectName -> "get_user_by_email"
    ListLoginTokensByUserEffectName -> "list_login_tokens_by_user"
    GetSessionByTokenEffectName -> "get_session_by_token"
    CreateUserEffectName -> "create_user"
    CreateSessionEffectName -> "create_session"
    CreateLoginTokenEffectName -> "create_login_token"
    UpdateLoginTokenEffectName -> "update_login_token"
  }
}
