import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/auth/domain/session/current as current_session
import glot_backend/request_policy/api_action as api_action_policy
import glot_backend/snippet/effect/effect as snippet_effect
import glot_backend/system/effect/error
import glot_backend/system/effect/program
import glot_backend/system/effect/program_types
import glot_backend/system/request/hydrated_context as request_context
import glot_backend/user_action/effect/effect as user_action_effect
import glot_core/admin/snippet_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/pagination_model

pub fn get_snippets(
  request_ctx: request_context.RequestContext,
  request: snippet_dto.ListSnippetsRequest,
) -> program_types.Program(snippet_dto.ListSnippetsResponse) {
  let pagination = request.pagination
  use _ <- program.and_then(
    pagination_model.validate(pagination, 100)
    |> result.map_error(error.validation)
    |> program.from_result,
  )
  use session <- program.and_then(current_session.require_session(request_ctx))
  use user_action <- program.and_then(api_action_policy.enforce(
    request_ctx: request_ctx,
    action: api_action.admin(admin_action.GetAdminSnippetsAction),
    actor: api_action_policy.actor_from_user(option.Some(session.user)),
  ))
  use snippets <- program.and_then(snippet_effect.list_admin(
    request.username,
    pagination_model.increment_limit(pagination),
  ))

  let page =
    pagination_model.paginate(snippets, pagination, fn(snippet) {
      pagination_model.from_string(snippet.identity.slug)
    })

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(snippet_dto.from_snippets(page))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.ListSnippetsRequest) {
  program.decode_dynamic(data, snippet_dto.list_request_decoder())
}
