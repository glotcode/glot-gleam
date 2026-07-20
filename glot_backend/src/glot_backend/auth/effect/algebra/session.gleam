import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/auth/session_model
import youid/uuid.{type Uuid}

pub type Effect(next) {
  ListSessionsByUserId(
    user_id: Uuid,
    created_since: Timestamp,
    last_activity_since: Timestamp,
    next: fn(List(session_model.Session)) -> next,
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
  DeleteSessionsByAccountId(
    account_id: Uuid,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  DeleteExpiredSessions(
    created_before: Timestamp,
    last_activity_before: Timestamp,
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
}

pub type EffectName {
  ListSessionsByUserIdEffectName
  GetSessionByTokenEffectName
  GetSessionByTokenForUpdateEffectName
  GetSessionByPreviousTokenEffectName
  GetSessionByPreviousTokenForUpdateEffectName
  DeleteSessionsByAccountIdEffectName
  DeleteExpiredSessionsEffectName
  CreateSessionEffectName
  UpdateSessionEffectName
  DeleteSessionEffectName
}

pub fn map(effect: Effect(a), f: fn(a) -> b) -> Effect(b) {
  case effect {
    ListSessionsByUserId(user_id:, created_since:, last_activity_since:, next:) ->
      ListSessionsByUserId(
        user_id: user_id,
        created_since: created_since,
        last_activity_since: last_activity_since,
        next: fn(value) { f(next(value)) },
      )
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
    DeleteSessionsByAccountId(account_id: account_id, next: next) ->
      DeleteSessionsByAccountId(account_id: account_id, next: fn(value) {
        f(next(value))
      })
    DeleteExpiredSessions(
      created_before: created_before,
      last_activity_before: last_activity_before,
      next: next,
    ) ->
      DeleteExpiredSessions(
        created_before: created_before,
        last_activity_before: last_activity_before,
        next: fn(value) { f(next(value)) },
      )
    CreateSession(session: session, next: next) ->
      CreateSession(session: session, next: fn(value) { f(next(value)) })
    UpdateSession(session:, next:) ->
      UpdateSession(session: session, next: fn(value) { f(next(value)) })
    DeleteSession(id: id, next: next) ->
      DeleteSession(id: id, next: fn(value) { f(next(value)) })
  }
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    ListSessionsByUserIdEffectName -> "list_sessions_by_user_id"
    GetSessionByTokenEffectName -> "get_session_by_token"
    GetSessionByTokenForUpdateEffectName -> "get_session_by_token_for_update"
    GetSessionByPreviousTokenEffectName -> "get_session_by_previous_token"
    GetSessionByPreviousTokenForUpdateEffectName ->
      "get_session_by_previous_token_for_update"
    DeleteSessionsByAccountIdEffectName -> "delete_sessions_by_account_id"
    DeleteExpiredSessionsEffectName -> "delete_expired_sessions"
    CreateSessionEffectName -> "create_session"
    UpdateSessionEffectName -> "update_session"
    DeleteSessionEffectName -> "delete_session"
  }
}
