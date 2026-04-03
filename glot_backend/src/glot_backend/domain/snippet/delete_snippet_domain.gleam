import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/authorization_domain
import glot_backend/domain/shared/rate_limit_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction_effect
import glot_backend/log
import glot_core/api_action
import glot_core/snippet

pub fn delete_snippet(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program_types.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use request <- program.and_then(program.decode_json(
    json_body,
    snippet.id_request_decoder(),
  ))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.id),
        log.uuid("user_id", session.user.id),
        log.uuid("snippet_id", request.id),
      ]),
    ),
  )

  use user_action_cmd <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.Some(session.user.id),
    action: api_action.DeleteSnippetAction,
  ))

  use existing_snippet <- program.and_then(
    snippet_effect.get_by_id(request.id)
    |> program.require(error.QueryError(error.DbQueryError("Snippet not found"))),
  )

  use _ <- program.and_then(authorization_domain.require_owner(
    session.user.id,
    existing_snippet.user_id,
  ))

  use _ <- program.and_then(
    transaction_effect.run_all([
      snippet_effect.delete(request.id),
      user_action_cmd,
    ]),
  )

  program.succeed(Nil)
}
