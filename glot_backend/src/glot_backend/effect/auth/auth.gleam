import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_core/auth
import glot_core/email
import glot_core/user
import youid/uuid.{type Uuid}

pub type AuthQueryName {
  GetUserByEmailQuery
  ListLoginTokensByUserQuery
  GetSessionByTokenQuery
}

pub type AuthCommandName {
  InsertUserCommand
  InsertSessionCommand
  InsertLoginTokenCommand
  UpdateLoginTokenCommand
}

pub type AuthEffect(next) {
  GetUserByEmail(
    email: email.Email,
    next: fn(option.Option(user.User)) -> next,
  )
  ListLoginTokensByUser(
    user_id: Uuid,
    limit: Int,
    next: fn(List(auth.LoginToken)) -> next,
  )
  GetSessionByToken(
    token: String,
    next: fn(option.Option(auth.Session)) -> next,
  )
  InsertUser(
    id: Uuid,
    email: String,
    created_at: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  InsertSession(
    id: Uuid,
    user_id: Uuid,
    token: String,
    ip: option.Option(String),
    user_agent: option.Option(String),
    created_at: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  InsertLoginToken(
    id: Uuid,
    user_id: Uuid,
    token: String,
    created_at: Timestamp,
    used_at: option.Option(Timestamp),
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
  UpdateLoginToken(
    user_id: Uuid,
    token: String,
    created_at: Timestamp,
    used_at: option.Option(Timestamp),
    id: Uuid,
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
    InsertUser(id:, email:, created_at:, next:) ->
      InsertUser(id:, email:, created_at:, next: fn(value) { f(next(value)) })
    InsertSession(
      id: id,
      user_id: user_id,
      token: token,
      ip: ip,
      user_agent: user_agent,
      created_at: created_at,
      next: next,
    ) ->
      InsertSession(
        id: id,
        user_id: user_id,
        token: token,
        ip: ip,
        user_agent: user_agent,
        created_at: created_at,
        next: fn(value) { f(next(value)) },
      )
    InsertLoginToken(
      id: id,
      user_id: user_id,
      token: token,
      created_at: created_at,
      used_at: used_at,
      next: next,
    ) ->
      InsertLoginToken(
        id: id,
        user_id: user_id,
        token: token,
        created_at: created_at,
        used_at: used_at,
        next: fn(value) { f(next(value)) },
      )
    UpdateLoginToken(
      user_id: user_id,
      token: token,
      created_at: created_at,
      used_at: used_at,
      id: id,
      next: next,
    ) ->
      UpdateLoginToken(
        user_id: user_id,
        token: token,
        created_at: created_at,
        used_at: used_at,
        id: id,
        next: fn(value) { f(next(value)) },
      )
  }
}
