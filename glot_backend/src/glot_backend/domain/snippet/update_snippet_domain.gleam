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
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_core/snippet/snippet_spam

pub fn update_snippet(
  ctx: context.Context,
  request: snippet_dto.UpdateSnippetRequest,
) -> program_types.Program(snippet_dto.SnippetResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.identity.id),
        log.uuid("user_id", session.user.identity.id),
        log.string("slug", request.slug),
      ]),
    ),
  )

  use user_action <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.Some(session.user.identity.id),
    action: api_action.UpdateSnippetAction,
  ))

  use existing_snippet <- program.and_then(
    snippet_effect.get_by_slug(request.slug)
    |> program.require(
      error.QueryError(error.DbQueryError("Snippet not found")),
    ),
  )

  use _ <- program.and_then(authorization_domain.require_owner(
    session.user.identity.id,
    existing_snippet.user.identity.id,
  ))

  use _ <- program.and_then(
    case snippet_spam.ensure_clean(request.data) {
      Ok(_) -> program.succeed(Nil)
      Error(message) -> program.fail(error.ValidationError(message))
    },
  )

  let updated_snippet =
    snippet_model.Snippet(
      id: existing_snippet.id,
      slug: existing_snippet.slug,
      user_id: existing_snippet.user.identity.id,
      title: request.data.title,
      language: request.data.language,
      visibility: request.data.visibility,
      stdin: request.data.stdin,
      run_instructions: request.data.run_instructions,
      files: request.data.files,
      created_at: existing_snippet.created_at,
      updated_at: ctx.timestamp,
    )

  use _ <- program.and_then(
    transaction_effect.run_all([
      snippet_effect.update_tx(updated_snippet),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )

  program.succeed(
    snippet_model.HydratedSnippet(
      id: updated_snippet.id,
      slug: updated_snippet.slug,
      user: existing_snippet.user,
      title: updated_snippet.title,
      language: updated_snippet.language,
      visibility: updated_snippet.visibility,
      stdin: updated_snippet.stdin,
      run_instructions: updated_snippet.run_instructions,
      files: updated_snippet.files,
      created_at: updated_snippet.created_at,
      updated_at: updated_snippet.updated_at,
    )
    |> snippet_dto.from_snippet,
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.UpdateSnippetRequest) {
  program.decode_dynamic(data, snippet_dto.update_decoder())
}
