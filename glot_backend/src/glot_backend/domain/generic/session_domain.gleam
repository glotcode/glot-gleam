import gleam/option
import gleam/time/timestamp
import glot_backend/context
import glot_backend/program
import glot_core/auth

pub fn require_session(ctx: context.Context) -> program.Program(auth.Session) {
  use session <- program.and_then(case ctx.client_info.session_token {
    option.Some(session_token) -> program.db_get_session_by_token(session_token)
    option.None ->
      program.fail(program.SessionError(program.MissingSessionTokenError))
  })

  case session {
    option.Some(session) ->
      case
        session_is_expired(
          session.created_at,
          ctx.timestamp,
          ctx.config.auth.session_token_max_age,
        )
      {
        True -> program.fail(program.SessionError(program.SessionExpiredError))
        False -> program.succeed(session)
      }
    option.None ->
      program.fail(program.SessionError(program.SessionNotFoundError))
  }
}

fn session_is_expired(
  created_at: timestamp.Timestamp,
  now: timestamp.Timestamp,
  max_age: Int,
) -> Bool {
  let #(created_seconds, _) =
    timestamp.to_unix_seconds_and_nanoseconds(created_at)
  let #(now_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(now)

  now_seconds >= created_seconds && now_seconds - created_seconds > max_age
}
