import gleam/dynamic
import gleam/option
import glot_backend/api_action
import glot_backend/context
import glot_backend/domain/generic/rate_limit_domain
import glot_backend/domain/generic/session_domain
import glot_backend/log
import glot_backend/program
import glot_core/snippet

pub fn snippet_create(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use request <- program.and_then(program.decode_json(
    json_body,
    snippet.decoder(),
  ))

  use _ <- program.and_then(
    program.log(
      log.from_list([
        log.uuid("session_id", session.id),
        log.uuid("user_id", session.user.id),
      ]),
    ),
  )

  use insert_activity_cmd <- program.and_then(rate_limit_domain.enforce(
    rate_limits: ctx.config.rate_limits.snippet_create,
    now: ctx.timestamp,
    ip: option.None,
    user_id: option.Some(session.user.id),
    action: api_action.SnippetCreateAction,
  ))

  use snippet_id <- program.and_then(program.uuid_v7())
  use _ <- program.and_then(
    program.run_in_transaction([
      program.DbInsertSnippet(
        id: snippet_id,
        user_id: session.user.id,
        snippet: request,
        created_at: ctx.timestamp,
        updated_at: ctx.timestamp,
      ),
      insert_activity_cmd,
    ]),
  )
  use _ <- program.and_then(
    program.log(log.singleton(log.uuid("snippet_id", snippet_id))),
  )

  program.succeed(Nil)
}
