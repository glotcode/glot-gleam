import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/pagination_model
import glot_core/public_action
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model

pub fn list_public_snippets(
  ctx: context.Context,
  request: snippet_dto.ListPublicSnippetsRequest,
) -> program_types.Program(snippet_dto.ListSnippetsResponse) {
  let pagination = request.pagination
  use _ <- program.and_then(
    pagination_model.validate(pagination, 100)
    |> result.map_error(error.ValidationError)
    |> program.from_result,
  )
  use maybe_session <- program.and_then(session_domain.get_session(ctx))
  let maybe_session_id =
    option.map(maybe_session, fn(session) { session.identity.id })
  let maybe_user_id =
    option.map(maybe_session, fn(session) { session.user.identity.id })

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.optional_uuid("session_id", maybe_session_id),
        log.optional_uuid("user_id", maybe_user_id),
      ]),
    ),
  )

  let actor =
    maybe_session
    |> option.map(fn(session) { session.user })
    |> api_action_policy_domain.actor_from_user

  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(public_action.ListPublicSnippetsAction),
    actor: actor,
  ))

  use snippets <- program.and_then(snippet_effect.list(
    filter: snippet_model.new_filter()
      |> snippet_model.only_visibilities([snippet_model.Public])
      |> snippet_model.only_usernames(request.usernames),
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
) -> program_types.Program(snippet_dto.ListPublicSnippetsRequest) {
  program.decode_dynamic(data, snippet_dto.list_public_decoder())
}
