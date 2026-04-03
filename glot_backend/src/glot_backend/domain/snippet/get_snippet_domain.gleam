import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/rate_limit_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/log
import glot_core/api_action
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model

pub fn get_snippet(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.SnippetResponse) {
  use request <- program.and_then(program.decode_json(
    json_body,
    snippet_dto.get_decoder(),
  ))

  use maybe_session <- program.and_then(session_domain.get_session(ctx))
  let maybe_session_id = option.map(maybe_session, fn(s) { s.id })
  let maybe_user_id = option.map(maybe_session, fn(s) { s.user.id })

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("snippet_id", request.id),
        log.optional_uuid("session_id", maybe_session_id),
        log.optional_uuid("user_id", maybe_user_id),
      ]),
    ),
  )

  use user_action_cmd <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: maybe_user_id,
    action: api_action.GetSnippetAction,
  ))

  use snippet <- program.and_then(
    snippet_effect.get_by_id(request.id)
    |> program.require(error.QueryError(error.DbQueryError("Snippet not found"))),
  )

  let is_owner = maybe_user_id == option.Some(snippet.user.id)

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.string(
          "visibility",
          snippet_model.visibility_to_string(snippet.visibility),
        ),
        log.bool("is_owner", is_owner),
      ]),
    ),
  )

  use _ <- program.and_then(user_action_cmd)

  program.succeed(snippet_dto.SnippetResponse(
    id: snippet.id,
    user: snippet.user,
    data: snippet_dto.SnippetData(
      title: snippet.title,
      language: snippet.language,
      visibility: snippet.visibility,
      stdin: snippet.stdin,
      run_command: snippet.run_command,
      files: snippet.files,
    ),
    created_at: snippet.created_at,
    updated_at: snippet.updated_at,
  ))
}
