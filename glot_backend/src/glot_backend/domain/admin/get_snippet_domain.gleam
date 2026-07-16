import gleam/dynamic
import gleam/option
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/error
import glot_backend/effect/error/resource_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/request_context
import glot_core/admin/snippet_dto
import glot_core/admin_action
import glot_core/api_action

pub fn get_snippet(
  request_ctx: request_context.RequestContext,
  request: snippet_dto.GetSnippetRequest,
) -> program_types.Program(snippet_dto.GetSnippetResponse) {
  use session <- program.and_then(session_domain.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.GetAdminSnippetAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use snippet <- program.and_then(
    snippet_effect.get_admin_by_slug(request.slug)
    |> program.require(error.resource(resource_error.SnippetNotFound)),
  )
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(snippet_dto.from_snippet(snippet))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.GetSnippetRequest) {
  program.decode_dynamic(data, snippet_dto.get_request_decoder())
}
