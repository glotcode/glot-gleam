import gleam/option.{type Option}
import gleam/result
import gleam/time/timestamp
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/auth/effect/session as session_effect
import glot_backend/auth/error as auth_error
import glot_backend/auth/model/config as auth_feature_config
import glot_backend/system/effect/error
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/context
import glot_backend/system/request/hydrated_context as request_context
import glot_core/auth/session_model

pub fn get_session(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(Option(session_model.HydratedSession)) {
  get_validated_session(
    request_ctx.context,
    dynamic_config.auth_config(request_ctx.dynamic_config),
  )
  |> program.map(option.from_result)
}

pub fn require_session(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(session_model.HydratedSession) {
  get_validated_session(
    request_ctx.context,
    dynamic_config.auth_config(request_ctx.dynamic_config),
  )
  |> program.and_then(program.from_result)
}

fn get_validated_session(
  ctx: context.Context,
  auth_config: auth_feature_config.AuthConfig,
) -> program_types.Program(Result(session_model.HydratedSession, error.Error)) {
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
    auth_config.session_idle_timeout_seconds,
  ))
  |> program.succeed
}

pub fn get_session_by_client_token(
  now: timestamp.Timestamp,
  token: String,
) -> program_types.Program(Result(session_model.HydratedSession, error.Error)) {
  use maybe_session <- program.and_then(session_effect.get_session_by_token(
    token,
  ))
  case maybe_session {
    option.Some(session) -> program.succeed(Ok(session))
    option.None ->
      session_effect.get_session_by_previous_token(token)
      |> program.map(result_from_previous_token(_, now))
  }
}

fn validate_session(
  session: session_model.HydratedSession,
  now: timestamp.Timestamp,
  session_max_lifetime: Int,
  session_idle_timeout_seconds: Int,
) -> Result(session_model.HydratedSession, error.Error) {
  let expired =
    is_expired(session.identity.created_at, now, session_max_lifetime)
    || is_expired(
      session.identity.last_activity_at,
      now,
      session_idle_timeout_seconds,
    )

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
