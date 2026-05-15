import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/snippet_dto
import glot_core/api_action
import glot_core/admin_action
import glot_core/pagination_model

pub fn get_snippets(
  ctx: context.Context,
  request: snippet_dto.ListSnippetsRequest,
) -> program_types.Program(snippet_dto.ListSnippetsResponse) {
  let pagination = request.pagination
  use _ <- program.and_then(
    pagination_model.validate(pagination, 100)
    |> result.map_error(error.ValidationError)
    |> program.from_result,
  )
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.GetAdminSnippetsAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
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
