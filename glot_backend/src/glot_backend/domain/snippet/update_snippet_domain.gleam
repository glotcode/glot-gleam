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
import glot_backend/effect/transaction/transaction_effect
import glot_backend/log
import glot_core/api_action
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model

pub fn update_snippet(
  ctx: context.Context,
  request: snippet_dto.UpdateSnippetRequest,
) -> program_types.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.id),
        log.uuid("user_id", session.user.id),
        log.string("slug", request.slug),
      ]),
    ),
  )

  use user_action_cmd <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.Some(session.user.id),
    action: api_action.UpdateSnippetAction,
  ))

  use existing_snippet <- program.and_then(
    snippet_effect.get_by_slug(request.slug)
    |> program.require(error.QueryError(error.DbQueryError("Snippet not found"))),
  )

  use _ <- program.and_then(authorization_domain.require_owner(
    session.user.id,
    existing_snippet.user.id,
  ))

  let updated_snippet =
    snippet_model.Snippet(
      id: existing_snippet.id,
      slug: existing_snippet.slug,
      user_id: existing_snippet.user.id,
      title: request.data.title,
      language: request.data.language,
      visibility: request.data.visibility,
      stdin: request.data.stdin,
      run_command: request.data.run_command,
      files: request.data.files,
      created_at: existing_snippet.created_at,
      updated_at: ctx.timestamp,
    )

  use _ <- program.and_then(
    transaction_effect.run_all([
      snippet_effect.update(updated_snippet),
      user_action_cmd,
    ]),
  )

  program.succeed(Nil)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.UpdateSnippetRequest) {
  program.decode_dynamic(data, snippet_dto.update_decoder())
}
