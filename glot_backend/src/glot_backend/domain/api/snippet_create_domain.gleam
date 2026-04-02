import gleam/dynamic
import gleam/option
import glot_core/api_action
import glot_backend/context
import glot_backend/domain/generic/rate_limit_domain
import glot_backend/domain/generic/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/program_types
import glot_backend/effect/program
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction_effect
import glot_backend/log
import glot_core/snippet

pub fn snippet_create(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program_types.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use request <- program.and_then(program.decode_json(
    json_body,
    snippet.decoder(),
  ))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.id),
        log.uuid("user_id", session.user.id),
      ]),
    ),
  )

  use user_action_cmd <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.Some(session.user.id),
    action: api_action.SnippetCreateAction,
  ))

  use snippet_id <- program.and_then(basic_effect.uuid_v7())
  use _ <- program.and_then(
    transaction_effect.run_all([
      snippet_effect.insert(
        id: snippet_id,
        user_id: session.user.id,
        snippet: request,
        created_at: ctx.timestamp,
        updated_at: ctx.timestamp,
      ),
      user_action_cmd,
    ]),
  )
  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.uuid("snippet_id", snippet_id))),
  )

  program.succeed(Nil)
}
