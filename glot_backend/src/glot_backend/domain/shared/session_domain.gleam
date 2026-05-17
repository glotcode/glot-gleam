import gleam/option.{type Option}
import gleam/result
import gleam/time/timestamp
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/error/auth_error
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
  let auth_config = dynamic_config.auth_config(config)
  use session_result <- program.and_then(case ctx.client_info.session_token {
    option.Some(token) -> get_session_by_client_token(ctx.timestamp, token)
    option.None ->
      program.succeed(Error(error.auth(auth_error.MissingSessionToken)))
  })

  session_result
  |> result.try(validate_session(
    _,
    ctx.timestamp,
    auth_config.session_token_max_age,
  ))
  |> program.succeed
}

pub fn get_session_by_client_token(
  now: timestamp.Timestamp,
  token: String,
) -> program_types.Program(Result(session_model.HydratedSession, error.Error)) {
  use maybe_session <- program.and_then(auth_effect.get_session_by_token(token))
  case maybe_session {
    option.Some(session) -> program.succeed(Ok(session))
    option.None ->
      auth_effect.get_session_by_previous_token(token)
      |> program.map(result_from_previous_token(_, now))
  }
}

fn validate_session(
  session: session_model.HydratedSession,
  now: timestamp.Timestamp,
  session_token_max_age: Int,
) -> Result(session_model.HydratedSession, error.Error) {
  let expired =
    is_expired(session.identity.created_at, now, session_token_max_age)

  case expired {
    True -> Error(error.auth(auth_error.SessionExpired))
    False -> Ok(session)
  }
}

fn result_from_previous_token(
  maybe_session: Option(session_model.HydratedSession),
  now: timestamp.Timestamp,
) -> Result(session_model.HydratedSession, error.Error) {
  case option.to_result(maybe_session, error.auth(auth_error.SessionNotFound)) {
    Ok(session) ->
      case validate_previous_token(session.identity, now) {
        Ok(_) -> Ok(session)
        Error(err) -> Error(err)
      }
    Error(err) -> Error(err)
  }
}

pub fn validate_previous_token(
  session: session_model.Session,
  now: timestamp.Timestamp,
) -> Result(Nil, error.Error) {
  case session.previous_token_valid_until {
    option.Some(valid_until) ->
      case timestamp_is_on_or_before(now, valid_until) {
        True -> Ok(Nil)
        False -> Error(error.auth(auth_error.SessionNotFound))
      }
    option.None -> Error(error.auth(auth_error.SessionNotFound))
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

fn timestamp_is_on_or_before(
  left: timestamp.Timestamp,
  right: timestamp.Timestamp,
) -> Bool {
  let #(left_seconds, left_nanos) =
    timestamp.to_unix_seconds_and_nanoseconds(left)
  let #(right_seconds, right_nanos) =
    timestamp.to_unix_seconds_and_nanoseconds(right)

  left_seconds < right_seconds
  || { left_seconds == right_seconds && left_nanos <= right_nanos }
}
