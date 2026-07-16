import gleam/dynamic
import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_backend/context
import glot_backend/domain/auth/session_issue_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/dynamic_config
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
import glot_backend/request_context
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
  request_ctx: request_context.RequestContext,
  request: login_dto.LoginRequest,
) -> program_types.Program(LoginResult) {
  let ctx = request_ctx.context
  let config = request_ctx.dynamic_config

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.email("email", request.email),
        log.string("token", request.token),
      ]),
    ),
  )
  let auth_config = dynamic_config.auth_config(config)

  use maybe_user <- program.and_then(auth_effect.get_user_by_email(
    request.email,
  ))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.public(public_action.LoginAction),
    actor: api_action_policy_domain.actor_from_user(maybe_user),
  ))

  use user_outcome <- program.and_then(update_or_create_user(
    maybe_user,
    request.email,
    ctx.timestamp,
  ))

  let user_outcome = mark_user_last_login(user_outcome, ctx.timestamp)
  let user = user_from_outcome(user_outcome)
  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.uuid("user_id", user.id))),
  )
  use session_issue <- program.and_then(
    session_issue_domain.issue_session_for_user(ctx, user.id),
  )
  let prepared_login =
    PreparedLogin(
      email: request.email,
      token: request.token,
      attempted_at: ctx.timestamp,
      valid_token_created_since: subtract_seconds(
        ctx.timestamp,
        auth_config.login_token_max_age,
      ),
      user_outcome: user_outcome,
      session_issue: session_issue,
      user_action: user_action,
    )
  use verification <- program.and_then(
    transaction_effect.run(login_tx(prepared_login)),
  )
  use _ <- program.and_then(case verification {
    ValidToken -> program.succeed(Nil)
    InvalidToken -> program.fail(error.auth(auth_error.InvalidLoginToken))
  })
  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session_issue.session.id),
        log.bool("is_first_login", is_new_user(user_outcome)),
      ]),
    ),
  )

  program.succeed(session_issue_domain.SessionIssueResult(
    session_token: session_issue.session_token,
    session_cookie_max_age: auth_config.session_cookie_max_age,
  ))
}

type PreparedLogin {
  PreparedLogin(
    email: EmailAddress,
    token: String,
    attempted_at: timestamp.Timestamp,
    valid_token_created_since: timestamp.Timestamp,
    user_outcome: UserOutcome,
    session_issue: session_issue_domain.SessionIssue,
    user_action: user_action.UserAction,
  )
}

fn login_tx(
  prepared_login: PreparedLogin,
) -> program_types.TransactionProgram(LoginTokenVerification) {
  // Keep this lookup in the transaction because the query locks the tokens with
  // FOR UPDATE, preventing concurrent login attempts from losing updates.
  use tokens <- transaction_program.and_then(
    auth_effect.list_login_tokens_by_email_tx(
      prepared_login.email,
      prepared_login.valid_token_created_since,
      valid_login_token_count,
    ),
  )
  let token_preparation =
    prepare_login_token_mutations(
      tokens,
      prepared_login.token,
      prepared_login.attempted_at,
    )
  let transaction =
    prepare_login_mutations(
      token_preparation,
      prepared_login.user_outcome,
      prepared_login.session_issue,
      prepared_login.user_action,
    )
  use _ <- transaction_program.and_then(transaction)

  transaction_program.succeed(token_preparation.verification)
}

type LoginTokenPreparation {
  LoginTokenPreparation(
    verification: LoginTokenVerification,
    attempt_transaction: program_types.TransactionProgram(Nil),
  )
}

fn prepare_login_token_mutations(
  tokens: List(login_token_model.LoginToken),
  provided_token: String,
  now: timestamp.Timestamp,
) -> LoginTokenPreparation {
  let shared_attempt_count =
    list.fold(tokens, 0, fn(count, token) {
      int.max(count, token.attempt_count)
    })

  case tokens, shared_attempt_count >= max_login_token_attempts {
    [], _ ->
      LoginTokenPreparation(InvalidToken, transaction_program.succeed(Nil))
    _, True ->
      LoginTokenPreparation(InvalidToken, transaction_program.succeed(Nil))
    _, False -> {
      let matching_token =
        tokens
        |> list.find(fn(token) { token.token == provided_token })
        |> option.from_result()
      let attempt_transaction =
        list.map(tokens, fn(token) {
          let token =
            login_token_model.increment_attempt(token, shared_attempt_count)
          let token = case matching_token {
            option.Some(matching) if matching.id == token.id ->
              login_token_model.mark_as_used(token, now)
            _ -> token
          }
          auth_effect.update_login_token_tx(token)
        })
        |> transaction_program.sequence
      let verification = case matching_token {
        option.Some(_) -> ValidToken
        option.None -> InvalidToken
      }

      LoginTokenPreparation(verification, attempt_transaction)
    }
  }
}

fn prepare_login_mutations(
  token_preparation: LoginTokenPreparation,
  user_outcome: UserOutcome,
  session_issue: session_issue_domain.SessionIssue,
  user_action: user_action.UserAction,
) -> program_types.TransactionProgram(Nil) {
  use _ <- transaction_program.and_then(token_preparation.attempt_transaction)

  case token_preparation.verification {
    InvalidToken -> transaction_program.succeed(Nil)
    ValidToken ->
      transaction_program.sequence([
        prepare_user_mutations(user_outcome),
        auth_effect.create_session_tx(session_issue.session),
        user_action_effect.create_user_action_tx(user_action),
      ])
  }
}

pub fn request_from_dynamic(
  ctx: context.Context,
  data: dynamic.Dynamic,
) -> program_types.Program(login_dto.LoginRequest) {
  program.decode_dynamic(data, login_dto.decoder(ctx.regexes.is_email))
}

type UserOutcome {
  ExistingUser(user: user_model.User)
  NewUser(user: user_model.User, account: account_model.Account)
}

fn update_or_create_user(
  maybe_user: option.Option(user_model.HydratedUser),
  email: EmailAddress,
  now: timestamp.Timestamp,
) -> program_types.Program(UserOutcome) {
  case maybe_user {
    option.Some(existing_user) -> {
      program.succeed(ExistingUser(existing_user.identity))
    }
    option.None -> {
      use user_id <- program.and_then(basic_effect.uuid_v7())
      use account_id <- program.and_then(basic_effect.uuid_v7())
      let new_account = new_account(account_id, now)
      let new_user = new_user(user_id, account_id, email, now)

      program.succeed(NewUser(new_user, new_account))
    }
  }
}

fn user_from_outcome(user_outcome: UserOutcome) -> user_model.User {
  case user_outcome {
    ExistingUser(user) -> user
    NewUser(user, _) -> user
  }
}

fn mark_user_last_login(
  user_outcome: UserOutcome,
  now: timestamp.Timestamp,
) -> UserOutcome {
  case user_outcome {
    ExistingUser(user) -> ExistingUser(user_model.mark_last_login(user, now))
    NewUser(user, account) ->
      NewUser(user_model.mark_last_login(user, now), account)
  }
}

fn is_new_user(user_outcome: UserOutcome) -> Bool {
  case user_outcome {
    ExistingUser(_) -> False
    NewUser(_, _) -> True
  }
}

fn prepare_user_mutations(
  user_outcome: UserOutcome,
) -> program_types.TransactionProgram(Nil) {
  case user_outcome {
    NewUser(user, account) ->
      transaction_program.sequence([
        auth_effect.create_account_tx(account),
        auth_effect.create_user_tx(user),
      ])
    ExistingUser(user) -> auth_effect.update_user_tx(user)
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
