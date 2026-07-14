import gleam/option
import glot_backend/browser_info
import glot_backend/context
import glot_backend/crypto_token
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/auth/session_model
import youid/uuid

pub type SessionIssueResult {
  SessionIssueResult(session_token: String, session_cookie_max_age: Int)
}

pub type SessionIssue {
  SessionIssue(session: session_model.Session, session_token: String)
}

pub fn issue_session_for_user(
  ctx: context.Context,
  user_id: uuid.Uuid,
) -> program_types.Program(SessionIssue) {
  use session_id <- program.and_then(basic_effect.uuid_v7())
  use session_token <- program.and_then(basic_effect.new_token(
    32,
    crypto_token.AlphaNumeric,
  ))
  let browser_info = browser_info.from_user_agent(ctx.client_info.user_agent)

  let session =
    session_model.Session(
      id: session_id,
      user_id: user_id,
      token: session_token,
      previous_token: option.None,
      previous_token_valid_until: option.None,
      ip: ctx.client_info.ip,
      os_name: browser_info.os_name,
      browser_name: browser_info.browser_name,
      user_agent: ctx.client_info.user_agent,
      created_at: ctx.timestamp,
      token_updated_at: ctx.timestamp,
      last_activity_at: ctx.timestamp,
    )

  program.succeed(SessionIssue(session: session, session_token: session_token))
}
