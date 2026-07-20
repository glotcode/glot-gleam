import gleam/dynamic
import gleam/option
import glot_backend/auth/domain/session/current as current_session
import glot_backend/request_policy/api_action as api_action_policy
import glot_backend/snippet/effect/effect as snippet_effect
import glot_backend/system/effect/error
import glot_backend/system/effect/error/resource_error
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/effect/transaction/transaction_effect
import glot_backend/system/request/hydrated_context as request_context
import glot_backend/user_action/effect/effect as user_action_effect
import glot_core/admin_action
import glot_core/api_action
import glot_core/snippet/snippet_dto

pub fn delete_snippet(
  request_ctx: request_context.RequestContext,
  request: snippet_dto.DeleteSnippetRequest,
) -> program_types.Program(Nil) {
  use session <- program.and_then(current_session.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.DeleteAdminSnippetAction),
    actor: api_action_policy.actor_from_user(option.Some(session.user)),
  ))
  use snippet <- program.and_then(
    snippet_effect.get_admin_by_slug(request.slug)
    |> program.require(error.resource(resource_error.SnippetNotFound)),
  )
  use _ <- program.and_then(
    transaction_effect.run_all([
      snippet_effect.delete_tx(snippet.identity.id),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )

  program.succeed(Nil)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.DeleteSnippetRequest) {
  program.decode_dynamic(data, snippet_dto.delete_decoder())
}
