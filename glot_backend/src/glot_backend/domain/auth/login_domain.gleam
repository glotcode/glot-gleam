import gleam/dynamic
import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_backend/context
import glot_backend/domain/shared/rate_limit_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction_effect
import glot_backend/log
import glot_core/api_action
import glot_core/auth/login_dto
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model

pub fn login(
  ctx: context.Context,
  request: login_dto.LoginRequest,
) -> program_types.Program(String) {
  use _ <- program.and_then(
    basic_effect.info(
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

  use user <- program.and_then(
    auth_effect.get_user_by_email(request.email)
    |> program.require(error.LoginError(error.InvalidTokenError)),
  )

  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.uuid("user_id", user.id))),
  )

  use tokens <- program.and_then(auth_effect.list_login_tokens_by_user(
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

  use session_id <- program.and_then(basic_effect.uuid_v7())
  use session_token <- program.and_then(basic_effect.new_token(32))

  let update_user_effect = case user.first_login_at {
    option.None -> {
      user
      |> user_model.mark_first_login(ctx.timestamp)
      |> auth_effect.update_user
    }
    option.Some(_) -> program.succeed(Nil)
  }

  use _ <- program.and_then(
    transaction_effect.run_all([
      auth_effect.update_login_token(login_token_model.mark_as_used(
        matching_token,
        ctx.timestamp,
      )),
      auth_effect.create_session(session_model.Session(
        id: session_id,
        user_id: user.id,
        token: session_token,
        ip: ctx.client_info.ip,
        user_agent: ctx.client_info.user_agent,
        created_at: ctx.timestamp,
      )),
      update_user_effect,
      user_action_cmd,
    ]),
  )
  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session_id),
        log.bool("is_first_login", option.is_none(user.first_login_at)),
      ]),
    ),
  )

  program.succeed(session_token)
}

pub fn request_from_dynamic(
  ctx: context.Context,
  data: dynamic.Dynamic,
) -> program_types.Program(login_dto.LoginRequest) {
  program.decode_dynamic(data, login_dto.decoder(ctx.regexes.is_email))
}

fn find_valid_token(
  tokens: List(login_token_model.LoginToken),
  submitted_token: String,
  now: timestamp.Timestamp,
  max_age: Int,
) -> Result(login_token_model.LoginToken, error.Error) {
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
