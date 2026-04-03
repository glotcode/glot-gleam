import gleam/option.{type Option}
import gleam/result
import gleam/time/timestamp
import glot_backend/context
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/session

pub fn get_session(
  ctx: context.Context,
) -> program_types.Program(Option(session.HydratedSession)) {
  get_validated_session(ctx)
  |> program.map(option.from_result)
}

pub fn require_session(
  ctx: context.Context,
) -> program_types.Program(session.HydratedSession) {
  get_validated_session(ctx)
  |> program.and_then(program.from_result)
}

fn get_validated_session(
  ctx: context.Context,
) -> program_types.Program(Result(session.HydratedSession, error.Error)) {
  use session_result <- program.and_then(case ctx.client_info.session_token {
    option.Some(token) ->
      auth_effect.db_get_session_by_token(token)
      |> program.map(option.to_result(
        _,
        error.SessionError(error.SessionNotFoundError),
      ))
    option.None ->
      program.succeed(Error(error.SessionError(error.MissingSessionTokenError)))
  })

  session_result
  |> result.try(validate_session(_, ctx))
  |> program.succeed
}

fn validate_session(
  session: session.HydratedSession,
  ctx: context.Context,
) -> Result(session.HydratedSession, error.Error) {
  let expired =
    is_expired(
      session.created_at,
      ctx.timestamp,
      ctx.config.auth.session_token_max_age,
    )

  case expired {
    True -> Error(error.SessionError(error.SessionExpiredError))
    False -> Ok(session)
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
