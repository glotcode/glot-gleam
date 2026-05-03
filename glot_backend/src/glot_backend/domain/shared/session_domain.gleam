import gleam/option.{type Option}
import gleam/result
import gleam/time/timestamp
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/auth/session_model

pub fn get_session(
  ctx: context.Context,
) -> program_types.Program(Option(session_model.HydratedSession)) {
  get_validated_session(ctx)
  |> program.map(option.from_result)
}

pub fn require_session(
  ctx: context.Context,
) -> program_types.Program(session_model.HydratedSession) {
  get_validated_session(ctx)
  |> program.and_then(program.from_result)
}

fn get_validated_session(
  ctx: context.Context,
) -> program_types.Program(Result(session_model.HydratedSession, error.Error)) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  use auth_config <- program.and_then(
    dynamic_config.require_auth_config(config)
    |> result.map_error(fn(message) {
      error.QueryError(error.DbQueryError(message))
    })
    |> program.from_result(),
  )
  use session_result <- program.and_then(case ctx.client_info.session_token {
    option.Some(token) ->
      auth_effect.get_session_by_token(token)
      |> program.map(option.to_result(
        _,
        error.SessionError(error.SessionNotFoundError),
      ))
    option.None ->
      program.succeed(Error(error.SessionError(error.MissingSessionTokenError)))
  })

  session_result
  |> result.try(validate_session(_, ctx.timestamp, auth_config.session_token_max_age))
  |> program.succeed
}

fn validate_session(
  session: session_model.HydratedSession,
  now: timestamp.Timestamp,
  session_token_max_age: Int,
) -> Result(session_model.HydratedSession, error.Error) {
  let expired =
    is_expired(
      session.identity.created_at,
      now,
      session_token_max_age,
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
