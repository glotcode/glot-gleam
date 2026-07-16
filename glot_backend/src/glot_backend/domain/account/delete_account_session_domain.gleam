import gleam/dynamic
import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/error/auth_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/request_context
import glot_core/api_action
import glot_core/auth/account_session_dto
import glot_core/public_action

pub fn delete_account_session(
  request_ctx: request_context.RequestContext,
  request: account_session_dto.DeleteAccountSessionRequest,
) -> program_types.Program(Nil) {
  let ctx = request_ctx.context
  let config = request_ctx.dynamic_config

  use session <- program.and_then(session_domain.require_session(request_ctx))
  let auth_config = dynamic_config.auth_config(config)
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.public(public_action.DeleteAccountSessionAction),
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))
  use sessions <- program.and_then(auth_effect.list_sessions_by_user_id(
    session.user.identity.id,
    subtract_seconds(ctx.timestamp, auth_config.session_token_max_age),
    subtract_seconds(ctx.timestamp, auth_config.session_idle_timeout_seconds),
  ))
  use account_session <- program.and_then(
    sessions
    |> list.find(fn(account_session) { account_session.id == request.id })
    |> option.from_result()
    |> program.from_option(error.auth(auth_error.NotOwner)),
  )
  use _ <- program.and_then(
    transaction_effect.run_all([
      auth_effect.delete_session_tx(account_session.id),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )

  program.succeed(Nil)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(account_session_dto.DeleteAccountSessionRequest) {
  program.decode_dynamic(
    data,
    account_session_dto.delete_account_session_request_decoder(),
  )
}

fn subtract_seconds(
  ts: timestamp.Timestamp,
  seconds: Int,
) -> timestamp.Timestamp {
  let #(unix_seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(unix_seconds - seconds, nanos)
}
