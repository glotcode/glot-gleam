import gleam/dynamic
import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_backend/context
import glot_backend/domain/auth/session_issue_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/error/auth_error
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
import glot_core/auth/user_model
import glot_core/email/email_address_model.{type EmailAddress}
import glot_core/public_action
import glot_core/user_action
import youid/uuid.{type Uuid}

pub type LoginResult =
  session_issue_domain.SessionIssueResult

const max_login_token_attempts = 10

const valid_login_token_count = 2

type LoginTokenVerification {
  ValidToken
  InvalidToken
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
    action: api_action.public(public_action.LoginAction),
    actor: api_action_policy_domain.actor_from_user(maybe_user),
  ))

  use user_outcome <- program.and_then(update_or_create_user(
    maybe_user,
    request.email,
    ctx.timestamp,
  ))

  let user = user_outcome.user |> user_model.mark_last_login(ctx.timestamp)
  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.uuid("user_id", user.id))),
  )
  use session_issue <- program.and_then(
    session_issue_domain.issue_session_for_user(ctx, user.id),
  )
  use verification <- program.and_then(
    transaction_effect.run(login_tx(
      request,
      ctx,
      auth_config.login_token_max_age,
      user_outcome,
      user,
      session_issue,
      user_action,
    )),
  )
  use _ <- program.and_then(case verification {
    ValidToken -> program.succeed(Nil)
    InvalidToken -> program.fail(error.auth(auth_error.InvalidLoginToken))
  })
  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session_issue.session.id),
        log.bool("is_first_login", user_outcome.is_new_user),
      ]),
    ),
  )

  program.succeed(session_issue_domain.SessionIssueResult(
    session_token: session_issue.session_token,
    session_cookie_max_age: auth_config.session_cookie_max_age,
  ))
}

fn login_tx(
  request: login_dto.LoginRequest,
  ctx: context.Context,
  login_token_max_age: Int,
  user_outcome: UserOutcome,
  user: user_model.User,
  session_issue: session_issue_domain.SessionIssue,
  user_action: user_action.UserAction,
) -> program_types.TransactionProgram(LoginTokenVerification) {
  use verification <- transaction_program.and_then(verify_login_token_tx(
    request,
    ctx,
    login_token_max_age,
  ))

  case verification {
    InvalidToken -> transaction_program.succeed(InvalidToken)
    ValidToken -> {
      use _ <- transaction_program.and_then(user_outcome.persist_fn(user))
      use _ <- transaction_program.and_then(auth_effect.create_session_tx(
        session_issue.session,
      ))
      use _ <- transaction_program.and_then(
        user_action_effect.create_user_action_tx(user_action),
      )
      transaction_program.succeed(ValidToken)
    }
  }
}

fn verify_login_token_tx(
  request: login_dto.LoginRequest,
  ctx: context.Context,
  login_token_max_age: Int,
) -> program_types.TransactionProgram(LoginTokenVerification) {
  use tokens <- transaction_program.and_then(
    auth_effect.list_login_tokens_by_email_tx(
      request.email,
      subtract_seconds(ctx.timestamp, login_token_max_age),
      valid_login_token_count,
    ),
  )

  let shared_attempt_count =
    list.fold(tokens, 0, fn(count, token) {
      int.max(count, token.attempt_count)
    })

  case tokens, shared_attempt_count >= max_login_token_attempts {
    [], _ -> transaction_program.succeed(InvalidToken)
    _, True -> transaction_program.succeed(InvalidToken)
    _, False -> {
      let matching_token =
        tokens
        |> list.find(fn(token) { token.token == request.token })
        |> option.from_result()
      let next_attempt_count = shared_attempt_count + 1
      let updated_tokens =
        list.map(tokens, fn(token) {
          let token =
            login_token_model.set_attempt_count(token, next_attempt_count)
          case matching_token {
            option.Some(matching) if matching.id == token.id ->
              login_token_model.mark_as_used(token, ctx.timestamp)
            _ -> token
          }
        })
      use _ <- transaction_program.and_then(
        transaction_program.sequence(list.map(
          updated_tokens,
          auth_effect.update_login_token_tx,
        )),
      )

      case matching_token {
        option.Some(_) -> transaction_program.succeed(ValidToken)
        option.None -> transaction_program.succeed(InvalidToken)
      }
    }
  }
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

fn subtract_seconds(
  ts: timestamp.Timestamp,
  seconds: Int,
) -> timestamp.Timestamp {
  let #(unix_seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(unix_seconds - seconds, nanos)
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
