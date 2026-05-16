import glot_backend/context
import glot_backend/crypto_token
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
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
import gleam/int
import gleam/option
import gleam/time/timestamp
import glot_core/api_action
import glot_core/public_action
import glot_core/auth/session_model
import glot_core/user_action

const refresh_rotation_interval_seconds = 300
const previous_token_grace_window_seconds = 60

pub type RefreshSessionResult {
  RefreshSessionResult(session_token: String, session_cookie_max_age: Int)
}

pub fn refresh_session(
  ctx: context.Context,
) -> program_types.Program(RefreshSessionResult) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.identity.id),
        log.uuid("user_id", session.user.identity.id),
      ]),
    ),
  )

  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let auth_config = dynamic_config.auth_config(config)

  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(public_action.RefreshSessionAction),
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))

  use session_token <- program.and_then(basic_effect.new_token(
    32,
    crypto_token.AlphaNumeric,
  ))

  use refresh_outcome <- program.and_then(
    transaction_effect.run(refresh_session_tx(ctx, session_token, user_action)),
  )

  program.succeed(RefreshSessionResult(
    session_token: refresh_outcome.session_token,
    session_cookie_max_age: auth_config.session_cookie_max_age,
  ))
}

type RefreshOutcome {
  RefreshOutcome(session_token: String)
}

fn refresh_session_tx(
  ctx: context.Context,
  session_token: String,
  user_action: user_action.UserAction,
) -> program_types.TransactionProgram(RefreshOutcome) {
  use token <- transaction_program.and_then(transaction_program.from_option(
    ctx.client_info.session_token,
    error.SessionError(error.MissingSessionTokenError),
  ))
  use session <- transaction_program.and_then(
    get_session_by_client_token_for_update(token, ctx.timestamp),
  )

  let next_session =
    case should_rotate_session(session, ctx.timestamp) {
      True ->
        session
        |> session_model.rotate_token(
          session_token,
          ctx.timestamp,
          add_seconds(ctx.timestamp, previous_token_grace_window_seconds),
        )
      False -> session
    }

  use _ <- transaction_program.and_then(auth_effect.update_session_tx(
    next_session,
  ))
  use _ <- transaction_program.and_then(
    user_action_effect.create_user_action_tx(user_action),
  )
  transaction_program.succeed(RefreshOutcome(session_token: next_session.token))
}

fn get_session_by_client_token_for_update(
  token: String,
  now: timestamp.Timestamp,
) -> program_types.TransactionProgram(session_model.Session) {
  use maybe_session <- transaction_program.and_then(
    auth_effect.get_session_by_token_for_update_tx(token),
  )
  case maybe_session {
    option.Some(session) -> transaction_program.succeed(session)
    option.None -> {
      use previous_session <- transaction_program.and_then(
        transaction_program.require(
          auth_effect.get_session_by_previous_token_for_update_tx(token),
          error.SessionError(error.SessionNotFoundError),
        ),
      )
      transaction_program.and_then(
        transaction_program.from_result(
          session_domain.validate_previous_token(previous_session, now),
        ),
        fn(_) { transaction_program.succeed(previous_session) },
      )
    }
  }
}

fn should_rotate_session(
  session: session_model.Session,
  now: timestamp.Timestamp,
) -> Bool {
  elapsed_seconds(session.token_updated_at, now) >= refresh_rotation_interval_seconds
}

fn add_seconds(ts: timestamp.Timestamp, seconds_to_add: Int) -> timestamp.Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(seconds + seconds_to_add, nanos)
}

fn elapsed_seconds(from: timestamp.Timestamp, to: timestamp.Timestamp) -> Int {
  let #(from_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(from)
  let #(to_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(to)
  int.absolute_value(to_seconds - from_seconds)
}
