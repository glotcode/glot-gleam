import gleam/dynamic
import gleam/option
import glot_backend/api_action
import glot_backend/context
import glot_backend/domain/generic/rate_limit_domain
import glot_backend/domain/generic/session_domain
import glot_backend/effect
import glot_backend/log
import glot_core/snippet

pub fn snippet_create(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> effect.Program(Nil) {
  use session <- effect.and_then(session_domain.require_session(ctx))

  use request <- effect.and_then(effect.decode_json(
    json_body,
    snippet.decoder(),
  ))

  use _ <- effect.and_then(
    effect.info(
      log.from_list([
        log.uuid("session_id", session.id),
        log.uuid("user_id", session.user.id),
      ]),
    ),
  )

  use user_action_cmd <- effect.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.Some(session.user.id),
    action: api_action.SnippetCreateAction,
  ))

  use snippet_id <- effect.and_then(effect.uuid_v7())
  use _ <- effect.and_then(
    effect.run_in_transaction([
      effect.DbInsertSnippet(
        id: snippet_id,
        user_id: session.user.id,
        snippet: request,
        created_at: ctx.timestamp,
        updated_at: ctx.timestamp,
      ),
      user_action_cmd,
    ]),
  )
  use _ <- effect.and_then(
    effect.info(log.singleton(log.uuid("snippet_id", snippet_id))),
  )

  effect.succeed(Nil)
}
