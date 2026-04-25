import gleam/dynamic
import gleam/list
import gleam/option
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
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model

pub fn list_public_snippets(
  ctx: context.Context,
  request: snippet_dto.ListPublicSnippetsRequest,
) -> program_types.Program(snippet_dto.ListPublicSnippetsResponse) {
  use _ <- program.and_then(validate_request(request))
  use maybe_session <- program.and_then(session_domain.get_session(ctx))
  let maybe_session_id = option.map(maybe_session, fn(session) { session.identity.id })
  let maybe_user_id = option.map(maybe_session, fn(session) { session.user.identity.id })

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
    action: api_action.ListPublicSnippetsAction,
    actor: actor,
  ))

  use snippets <- program.and_then(snippet_effect.list(
    visibilities: [snippet_model.Public],
    skip_user_ids: [],
    cursor_slug: request.cursor,
    limit: request.limit + 1,
  ))

  let #(page, next_cursor) = paginate_snippets(snippets, request.limit)

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(
    snippet_dto.from_public_snippets(page, next_cursor),
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.ListPublicSnippetsRequest) {
  program.decode_dynamic(data, snippet_dto.list_public_decoder())
}

fn validate_request(
  request: snippet_dto.ListPublicSnippetsRequest,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(require(
    request.limit > 0,
    "limit must be greater than 0",
  ))
  use _ <- program.and_then(require(
    request.limit <= 100,
    "limit must be less than or equal to 100",
  ))

  program.succeed(Nil)
}

fn require(condition: Bool, message: String) -> program_types.Program(Nil) {
  case condition {
    True -> program.succeed(Nil)
    False -> program.fail(error.ValidationError(message))
  }
}

fn paginate_snippets(
  snippets: List(snippet_model.HydratedSnippet),
  limit: Int,
) -> #(List(snippet_model.HydratedSnippet), option.Option(String)) {
  paginate_snippets_loop(snippets, limit, [], option.None)
}

fn paginate_snippets_loop(
  snippets: List(snippet_model.HydratedSnippet),
  remaining: Int,
  acc: List(snippet_model.HydratedSnippet),
  last_slug: option.Option(String),
) -> #(List(snippet_model.HydratedSnippet), option.Option(String)) {
  case snippets {
    [] -> #(list.reverse(acc), option.None)
    [snippet, ..rest] ->
      case remaining > 0 {
        True ->
          paginate_snippets_loop(
            rest,
            remaining - 1,
            [snippet, ..acc],
            option.Some(snippet.identity.slug),
          )
        False -> #(list.reverse(acc), last_slug)
      }
  }
}
