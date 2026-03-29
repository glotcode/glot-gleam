import gleam/dynamic
import glot_backend/api_action
import glot_backend/context
import glot_backend/domain/generic/rate_limit_domain
import glot_backend/domain/generic/session_domain
import glot_backend/program

pub fn snippet_create(
  ctx: context.Context,
  _json_body: dynamic.Dynamic,
) -> program.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use _ <- program.and_then(rate_limit_domain.enforce_by_user(
    rate_limits: ctx.config.rate_limits.snippet_create,
    now: ctx.timestamp,
    user_id: session.user.id,
    action: api_action.SnippetCreateAction,
  ))

  program.succeed(Nil)
}
