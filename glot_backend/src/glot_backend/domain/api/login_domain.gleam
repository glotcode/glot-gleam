import gleam/dynamic
import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_backend/api_action
import glot_backend/context
import glot_backend/domain/generic/rate_limit_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/core/core_effect
import glot_backend/effect/program_types
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/transaction_effect
import glot_backend/log
import glot_core/auth
import glot_core/user

pub fn login(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program_types.Program(String) {
  use request <- program.and_then(program.decode_json(
    json_body,
    auth.login_request_decoder(ctx.regexes.is_email),
  ))

  use _ <- program.and_then(
    core_effect.info(
      log.from_list([
        log.email("email", request.email),
        log.string("token", request.token),
      ]),
    ),
  )

  use user_action_cmd <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.None,
    action: api_action.LoginAction,
  ))

  use maybe_user <- program.and_then(auth_effect.db_get_user_by_email(request.email))
  use user <- program.and_then(
    program.from_result(user_from_option(maybe_user)),
  )

  use _ <- program.and_then(
    core_effect.info(log.singleton(log.uuid("user_id", user.id))),
  )

  use tokens <- program.and_then(auth_effect.db_list_login_tokens_by_user(
    user.id,
    10,
  ))
  use matching_token <- program.and_then(
    program.from_result(find_valid_token(
      tokens,
      request.token,
      ctx.timestamp,
      ctx.config.auth.login_token_max_age,
    )),
  )

  use session_id <- program.and_then(core_effect.uuid_v7())
  use session_token <- program.and_then(core_effect.new_token(32))

  use _ <- program.and_then(
    transaction_effect.run_all([
      auth_effect.update_login_token(
        user_id: user.id,
        token: matching_token.token,
        created_at: matching_token.created_at,
        used_at: option.Some(ctx.timestamp),
        id: matching_token.id,
      ),
      auth_effect.insert_session(
        id: session_id,
        user_id: user.id,
        token: session_token,
        ip: ctx.client_info.ip,
        user_agent: ctx.client_info.user_agent,
        created_at: ctx.timestamp,
      ),
      user_action_cmd,
    ]),
  )
  use _ <- program.and_then(
    core_effect.info(log.singleton(log.uuid("session_id", session_id))),
  )

  program.succeed(session_token)
}

fn user_from_option(
  maybe_user: option.Option(user.User),
) -> Result(user.User, error.Error) {
  case maybe_user {
    option.Some(user) -> Ok(user)
    option.None -> Error(error.LoginError(error.InvalidTokenError))
  }
}

fn find_valid_token(
  tokens: List(auth.LoginToken),
  submitted_token: String,
  now: timestamp.Timestamp,
  max_age: Int,
) -> Result(auth.LoginToken, error.Error) {
  case list.find(tokens, fn(token) { token.token == submitted_token }) {
    Error(_) -> Error(error.LoginError(error.InvalidTokenError))
    Ok(token) ->
      case token.used_at {
        option.Some(_) -> Error(error.LoginError(error.TokenUsedError))
        option.None ->
          case token_is_still_valid(token.created_at, now, max_age) {
            True -> Ok(token)
            False -> Error(error.LoginError(error.TokenExpiredError))
          }
      }
  }
}

fn token_is_still_valid(
  created_at: timestamp.Timestamp,
  now: timestamp.Timestamp,
  max_age: Int,
) -> Bool {
  let #(created_seconds, _) =
    timestamp.to_unix_seconds_and_nanoseconds(created_at)
  let #(now_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(now)

  now_seconds >= created_seconds && now_seconds - created_seconds <= max_age
}
