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
import glot_backend/system/request/hydrated_context as request_context
import glot_backend/user_action/effect/effect as user_action_effect
import glot_core/api_action
import glot_core/pagination_model
import glot_core/public_action
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model

pub fn list_session_snippets(
  request_ctx: request_context.RequestContext,
  request: snippet_dto.ListSessionSnippetsRequest,
) -> program_types.Program(snippet_dto.ListSnippetsResponse) {
  let pagination = request.pagination
  use _ <- program.and_then(
    pagination_model.validate(pagination, 100)
    |> result.map_error(error.validation)
    |> program.from_result,
  )
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
    action: api_action.public(public_action.ListSessionSnippetsAction),
    actor: api_action_policy.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))

  use snippets <- program.and_then(snippet_effect.list(
    filter: snippet_model.new_filter()
      |> snippet_model.only_user_ids([session.user.identity.id]),
    pagination: pagination_model.increment_limit(pagination),
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
) -> program_types.Program(snippet_dto.ListSessionSnippetsRequest) {
  program.decode_dynamic(data, snippet_dto.list_session_decoder())
}
