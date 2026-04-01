import gleam/option.{type Option}
import gleam/result
import gleam/time/timestamp
import glot_backend/context
import glot_backend/effect.{type Free}
import glot_core/auth

pub fn get_session(
  ctx: context.Context,
) -> Free(Option(auth.Session)) {
  use session <- effect.and_then(case ctx.client_info.session_token {
    option.Some(session_token) ->
      effect.db_get_session_by_token(session_token)
    option.None -> effect.succeed(option.None)
  })

  validate_session(ctx, session)
  |> option.from_result
  |> effect.succeed()
}

pub fn require_session(ctx: context.Context) -> Free(auth.Session) {
  use session <- effect.and_then(case ctx.client_info.session_token {
    option.Some(session_token) ->
      effect.db_get_session_by_token(session_token)
    option.None ->
      effect.fail(effect.SessionError(effect.MissingSessionTokenError))
  })

  validate_session(ctx, session)
  |> result.map_error(effect.SessionError)
  |> effect.from_result
}

fn validate_session(
  ctx: context.Context,
  session: Option(auth.Session),
) -> Result(auth.Session, effect.SessionError) {
  case session {
    option.Some(session) ->
      case
        is_expired(
          session.created_at,
          ctx.timestamp,
          ctx.config.auth.session_token_max_age,
        )
      {
        True -> Error(effect.SessionExpiredError)
        False -> Ok(session)
      }
    option.None -> Error(effect.SessionNotFoundError)
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
