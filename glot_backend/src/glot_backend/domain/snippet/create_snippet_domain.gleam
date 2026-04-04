import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/rate_limit_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction/transaction_effect
import glot_backend/log
import glot_core/api_action
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model

pub fn create_snippet(
  ctx: context.Context,
  request: snippet_dto.CreateSnippetRequest,
) -> program_types.Program(snippet_dto.SnippetResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))

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
    action: api_action.CreateSnippetAction,
  ))

  use snippet_id <- program.and_then(basic_effect.uuid_v7())
  let new_snippet =
    snippet_model.Snippet(
      id: snippet_id,
      slug: snippet_model.new_slug(ctx.timestamp),
      user_id: session.user.id,
      title: request.data.title,
      language: request.data.language,
      visibility: request.data.visibility,
      stdin: request.data.stdin,
      run_command: request.data.run_command,
      files: request.data.files,
      created_at: ctx.timestamp,
      updated_at: ctx.timestamp,
    )
  use _ <- program.and_then(
    transaction_effect.run_all([
      snippet_effect.create(new_snippet),
      user_action_cmd,
    ]),
  )
  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.uuid("snippet_id", snippet_id))),
  )

  program.succeed(
    snippet_model.HydratedSnippet(
      id: new_snippet.id,
      slug: new_snippet.slug,
      user: session.user,
      title: new_snippet.title,
      language: new_snippet.language,
      visibility: new_snippet.visibility,
      stdin: new_snippet.stdin,
      run_command: new_snippet.run_command,
      files: new_snippet.files,
      created_at: new_snippet.created_at,
      updated_at: new_snippet.updated_at,
    )
    |> snippet_dto.from_snippet,
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.CreateSnippetRequest) {
  program.decode_dynamic(data, snippet_dto.create_decoder())
}
