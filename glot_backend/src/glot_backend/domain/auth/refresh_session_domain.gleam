import gleam/int
import gleam/option
import gleam/time/timestamp
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
import glot_core/api_action
import glot_core/auth/refresh_session_dto
import glot_core/auth/session_model
import glot_core/public_action
import glot_core/user_action

pub type RefreshSessionResult {
  RefreshSessionResult(
    session_token: String,
    session_cookie_max_age: Int,
    response: refresh_session_dto.RefreshSessionResponse,
  )
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

  use rotation_outcome <- program.and_then(
    transaction_effect.run(refresh_session_tx(
      ctx,
      session_token,
      user_action,
      auth_config,
    )),
  )

  use _ <- program.and_then(
    basic_effect.info(log.from_list([
      log.uuid("session_id", session.identity.id),
      log.uuid("user_id", session.user.identity.id),
      log.bool("token_rotated", rotation_outcome.rotated),
      log.int(
        "next_heartbeat_in_seconds",
        rotation_outcome.next_heartbeat_in_seconds,
      ),
    ])),
  )

  program.succeed(RefreshSessionResult(
    session_token: rotation_outcome.session_token,
    session_cookie_max_age: auth_config.session_cookie_max_age,
    response: refresh_session_dto.RefreshSessionResponse(
      next_heartbeat_in_seconds: rotation_outcome.next_heartbeat_in_seconds,
    ),
  ))
}

type RotationOutcome {
  RotationOutcome(
    rotated: Bool,
    session_token: String,
    next_heartbeat_in_seconds: Int,
  )
}

fn refresh_session_tx(
  ctx: context.Context,
  session_token: String,
  user_action: user_action.UserAction,
  auth_config: dynamic_config.AuthConfig,
) -> program_types.TransactionProgram(RotationOutcome) {
  use token <- transaction_program.and_then(transaction_program.from_option(
    ctx.client_info.session_token,
    error.SessionError(error.MissingSessionTokenError),
  ))
  use session <- transaction_program.and_then(
    get_session_by_client_token_for_update(token, ctx.timestamp),
  )

  let token_rotated = should_rotate_session_token(
    session,
    ctx.timestamp,
    auth_config.session_refresh_interval_seconds,
  )

  let next_session = case token_rotated {
    True ->
      session
      |> session_model.rotate_token(
        session_token,
        ctx.timestamp,
        add_seconds(
          ctx.timestamp,
          auth_config.session_previous_token_grace_seconds,
        ),
      )
    False -> session
  }

  use _ <- transaction_program.and_then(auth_effect.update_session_tx(
    next_session,
  ))
  use _ <- transaction_program.and_then(
    user_action_effect.create_user_action_tx(user_action),
  )
  transaction_program.succeed(RotationOutcome(
    rotated: token_rotated,
    session_token: next_session.token,
    next_heartbeat_in_seconds: next_heartbeat_in_seconds(
      next_session,
      ctx.timestamp,
      auth_config,
    ),
  ))
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
        transaction_program.from_result(session_domain.validate_previous_token(
          previous_session,
          now,
        )),
        fn(_) { transaction_program.succeed(previous_session) },
      )
    }
  }
}

fn should_rotate_session_token(
  session: session_model.Session,
  now: timestamp.Timestamp,
  session_refresh_interval_seconds: Int,
) -> Bool {
  elapsed_seconds(session.token_updated_at, now)
  >= session_refresh_interval_seconds
}

fn add_seconds(
  ts: timestamp.Timestamp,
  seconds_to_add: Int,
) -> timestamp.Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(seconds + seconds_to_add, nanos)
}

fn elapsed_seconds(from: timestamp.Timestamp, to: timestamp.Timestamp) -> Int {
  let #(from_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(from)
  let #(to_seconds, _) = timestamp.to_unix_seconds_and_nanoseconds(to)
  int.absolute_value(to_seconds - from_seconds)
}

fn next_heartbeat_in_seconds(
  session: session_model.Session,
  now: timestamp.Timestamp,
  auth_config: dynamic_config.AuthConfig,
) -> Int {
  let remaining =
    remaining_seconds_until_rotation(
      session.token_updated_at,
      now,
      auth_config.session_refresh_interval_seconds,
    )

  case remaining <= 0 {
    True -> auth_config.session_heartbeat_interval_seconds
    False -> min_int(auth_config.session_heartbeat_interval_seconds, remaining)
  }
}

fn remaining_seconds_until_rotation(
  session_token_updated_at: timestamp.Timestamp,
  now: timestamp.Timestamp,
  session_refresh_interval_seconds: Int,
) -> Int {
  session_refresh_interval_seconds
  - elapsed_seconds(session_token_updated_at, now)
}

fn min_int(a: Int, b: Int) -> Int {
  case a <= b {
    True -> a
    False -> b
  }
}
