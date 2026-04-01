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

pub type AuthCommand {
  InsertUser(id: Uuid, email: String, created_at: Timestamp)
  InsertSession(
    id: Uuid,
    user_id: Uuid,
    token: String,
    ip: option.Option(String),
    user_agent: option.Option(String),
    created_at: Timestamp,
  )
  InsertLoginToken(
    id: Uuid,
    user_id: Uuid,
    token: String,
    created_at: Timestamp,
    used_at: option.Option(Timestamp),
  )
  UpdateLoginToken(
    user_id: Uuid,
    token: String,
    created_at: Timestamp,
    used_at: option.Option(Timestamp),
    id: Uuid,
  )
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
  RunCommand(
    AuthCommand,
    fn(Result(Nil, error.DbCommandError)) -> next,
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
    RunCommand(command, next) -> RunCommand(command, fn(value) { f(next(value)) })
  }
}

pub fn command_name(command: AuthCommand) -> AuthCommandName {
  case command {
    InsertUser(_, _, _) -> InsertUserCommand
    InsertSession(_, _, _, _, _, _) -> InsertSessionCommand
    InsertLoginToken(_, _, _, _, _) -> InsertLoginTokenCommand
    UpdateLoginToken(_, _, _, _, _) -> UpdateLoginTokenCommand
  }
}
