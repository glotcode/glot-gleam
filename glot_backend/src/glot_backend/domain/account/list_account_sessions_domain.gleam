import gleam/list
import gleam/time/timestamp
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/dynamic_config
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/request_context
import glot_core/api_action
import glot_core/auth/account_session_dto
import glot_core/public_action

pub fn list_account_sessions(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(account_session_dto.ListAccountSessionsResponse) {
  let ctx = request_ctx.context
  let config = request_ctx.dynamic_config

  use session <- program.and_then(session_domain.require_session(request_ctx))
  let auth_config = dynamic_config.auth_config(config)
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.public(public_action.ListAccountSessionsAction),
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))
  use sessions <- program.and_then(auth_effect.list_sessions_by_user_id(
    session.user.identity.id,
    subtract_seconds(ctx.timestamp, auth_config.session_token_max_age),
    subtract_seconds(ctx.timestamp, auth_config.session_idle_timeout_seconds),
  ))

  program.succeed(
    account_session_dto.ListAccountSessionsResponse(
      sessions: list.map(sessions, fn(session) {
        account_session_dto.AccountSessionResponse(
          id: session.id,
          ip: session.ip,
          os_name: session.os_name,
          browser_name: session.browser_name,
          created_at: session.created_at,
          last_activity_at: session.last_activity_at,
        )
      }),
    ),
  )
}

fn subtract_seconds(
  ts: timestamp.Timestamp,
  seconds: Int,
) -> timestamp.Timestamp {
  let #(unix_seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(unix_seconds - seconds, nanos)
}
