import gleam/option.{type Option}
import gleam/result
import gleam/time/timestamp
import glot_backend/context
import glot_backend/effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_core/auth

pub fn get_session(
  ctx: context.Context,
) -> effect.Program(Option(auth.Session)) {
  use session <- program.and_then(case ctx.client_info.session_token {
    option.Some(session_token) ->
      auth_effect.db_get_session_by_token(session_token)
    option.None -> program.succeed(option.None)
  })

  validate_session(ctx, session)
  |> option.from_result
  |> program.succeed()
}

pub fn require_session(ctx: context.Context) -> effect.Program(auth.Session) {
  use session <- program.and_then(case ctx.client_info.session_token {
    option.Some(session_token) ->
      auth_effect.db_get_session_by_token(session_token)
    option.None ->
      program.fail(error.SessionError(error.MissingSessionTokenError))
  })

  validate_session(ctx, session)
  |> result.map_error(error.SessionError)
  |> program.from_result
}

fn validate_session(
  ctx: context.Context,
  session: Option(auth.Session),
) -> Result(auth.Session, error.SessionError) {
  case session {
    option.Some(session) ->
      case
        is_expired(
          session.created_at,
          ctx.timestamp,
          ctx.config.auth.session_token_max_age,
        )
      {
        True -> Error(error.SessionExpiredError)
        False -> Ok(session)
      }
    option.None -> Error(error.SessionNotFoundError)
  }
}

fn is_expired(
  created_at: timestamp.Timestamp,
  now: timestamp.Timestamp,
  max_age: Int,
) -> Bool {
  let #(created_seconds, _) =
    timestamp.to_unix_seconds_and_nanoseconds(created_at)
  let #(now_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(now)

  now_seconds >= created_seconds && now_seconds - created_seconds > max_age
}
