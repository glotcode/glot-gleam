import gleam/dynamic
import gleam/result
import glot_backend/auth/domain/session/current as current_session
import glot_backend/request_policy/api_action as api_action_policy
import glot_backend/snippet/effect/effect as snippet_effect
import glot_backend/system/effect/basic/basic_effect
import glot_backend/system/effect/error
import glot_backend/system/effect/log
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/effect/transaction/transaction_effect
import glot_backend/system/request/hydrated_context as request_context
import glot_backend/user_action/effect/effect as user_action_effect
import glot_core/api_action
import glot_core/public_action
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_core/snippet/snippet_spam

pub fn create_snippet(
  request_ctx: request_context.RequestContext,
  request: snippet_dto.CreateSnippetRequest,
) -> program_types.Program(snippet_dto.SnippetResponse) {
  let ctx = request_ctx.context

  use session <- program.and_then(current_session.require_session(request_ctx))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.identity.id),
        log.uuid("user_id", session.user.identity.id),
      ]),
    ),
  )

  use user_action <- program.and_then(api_action_policy.enforce(
    request_ctx: request_ctx,
    action: api_action.public(public_action.CreateSnippetAction),
    actor: api_action_policy.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))

  use _ <- program.and_then(
    snippet_model.validate_fields(
      request.data.title,
      request.data.stdin,
      request.data.run_instructions,
      request.data.files,
    )
    |> result.map_error(error.validation)
    |> program.from_result,
  )

  use _ <- program.and_then(
    snippet_spam.ensure_clean(request.data)
    |> result.map_error(error.validation)
    |> program.from_result,
  )

  use snippet_id <- program.and_then(basic_effect.uuid_v7())
  let new_snippet =
    snippet_model.Snippet(
      id: snippet_id,
      slug: snippet_model.new_slug(ctx.timestamp),
      user_id: session.user.identity.id,
      title: request.data.title,
      language: request.data.language,
      visibility: request.data.visibility,
      stdin: request.data.stdin,
      run_instructions: request.data.run_instructions,
      files: request.data.files,
      created_at: ctx.timestamp,
      updated_at: ctx.timestamp,
    )
  use _ <- program.and_then(
    transaction_effect.run_all([
      snippet_effect.create_tx(new_snippet),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )
  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.uuid("snippet_id", snippet_id))),
  )

  program.succeed(
    snippet_model.HydratedSnippet(
      identity: new_snippet,
      user: session.user.identity,
    )
    |> snippet_dto.from_snippet,
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.CreateSnippetRequest) {
  program.decode_dynamic(data, snippet_dto.create_decoder())
}
