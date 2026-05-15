import gleam/dynamic
import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_backend/context
import glot_backend/crypto_token
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/transaction/transaction_program
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/auth/login_dto
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model.{type EmailAddress}
import youid/uuid.{type Uuid}

pub type LoginResult {
  LoginResult(session_token: String, session_cookie_max_age: Int)
}

pub fn login(
  ctx: context.Context,
  request: login_dto.LoginRequest,
) -> program_types.Program(LoginResult) {
  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.email("email", request.email),
        log.string("token", request.token),
      ]),
    ),
  )
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let auth_config = dynamic_config.auth_config(config)

  use maybe_user <- program.and_then(auth_effect.get_user_by_email(
    request.email,
  ))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(api_action.LoginAction),
    actor: api_action_policy_domain.actor_from_user(maybe_user),
  ))

  use tokens <- program.and_then(auth_effect.list_login_tokens_by_email(
    request.email,
    10,
  ))
  use matching_token <- program.and_then(
    program.from_result(find_valid_token(
      tokens,
      request.token,
      ctx.timestamp,
      auth_config.login_token_max_age,
    )),
  )
  let used_login_token =
    login_token_model.mark_as_used(matching_token, ctx.timestamp)

  use session_id <- program.and_then(basic_effect.uuid_v7())
  use session_token <- program.and_then(basic_effect.new_token(
    32,
    crypto_token.AlphaNumeric,
  ))

  use user_outcome <- program.and_then(update_or_create_user(
    maybe_user,
    request.email,
    ctx.timestamp,
  ))

  let user = user_outcome.user |> user_model.mark_last_login(ctx.timestamp)

  let session =
    session_model.Session(
      id: session_id,
      user_id: user.id,
      token: session_token,
      ip: ctx.client_info.ip,
      user_agent: ctx.client_info.user_agent,
      created_at: ctx.timestamp,
    )

  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.uuid("user_id", user.id))),
  )

  use _ <- program.and_then(
    transaction_effect.run_all([
      auth_effect.update_login_token_tx(used_login_token),
      user_outcome.persist_fn(user),
      auth_effect.create_session_tx(session),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session_id),
        log.bool("is_first_login", user_outcome.is_new_user),
      ]),
    ),
  )

  program.succeed(LoginResult(
    session_token: session_token,
    session_cookie_max_age: auth_config.session_cookie_max_age,
  ))
}

pub fn request_from_dynamic(
  ctx: context.Context,
  data: dynamic.Dynamic,
) -> program_types.Program(login_dto.LoginRequest) {
  program.decode_dynamic(data, login_dto.decoder(ctx.regexes.is_email))
}

type UserOutcome {
  UserOutcome(
    user: user_model.User,
    is_new_user: Bool,
    persist_fn: fn(user_model.User) -> program_types.TransactionProgram(Nil),
  )
}

fn update_or_create_user(
  maybe_user: option.Option(user_model.HydratedUser),
  email: EmailAddress,
  now: timestamp.Timestamp,
) -> program_types.Program(UserOutcome) {
  case maybe_user {
    option.Some(existing_user) -> {
      program.succeed(
        UserOutcome(
          user: existing_user.identity,
          is_new_user: False,
          persist_fn: fn(user) { auth_effect.update_user_tx(user) },
        ),
      )
    }
    option.None -> {
      use user_id <- program.and_then(basic_effect.uuid_v7())
      use account_id <- program.and_then(basic_effect.uuid_v7())
      let new_account = new_account(account_id, now)
      let new_user = new_user(user_id, account_id, email, now)

      program.succeed(
        UserOutcome(user: new_user, is_new_user: True, persist_fn: fn(user) {
          use _ <- transaction_program.and_then(auth_effect.create_account_tx(
            new_account,
          ))
          auth_effect.create_user_tx(user)
        }),
      )
    }
  }
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

fn new_user(
  id: Uuid,
  account_id: Uuid,
  email: EmailAddress,
  now: timestamp.Timestamp,
) -> user_model.User {
  user_model.User(
    id: id,
    account_id: account_id,
    email: email,
    username: uuid.to_string(id),
    role: user_model.RegularUser,
    last_login_at: now,
    created_at: now,
    updated_at: now,
  )
}

fn new_account(id: Uuid, now: timestamp.Timestamp) -> account_model.Account {
  account_model.Account(
    id: id,
    account_state: account_model.Active,
    account_state_reason: option.None,
    account_tier: account_model.FreeTier,
    delete_job_id: option.None,
    created_at: now,
    updated_at: now,
  )
}
