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

type PageDirection {
  InitialPage
  AfterPage
  BeforePage
}

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
    usernames: request.usernames,
    skip_user_ids: [],
    after_slug: request.after,
    before_slug: request.before,
    limit: request.limit + 1,
  ))

  let #(page, previous_cursor, next_cursor) =
    paginate_snippets(snippets, request)

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(
    snippet_dto.from_public_snippets(page, previous_cursor, next_cursor),
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
  use _ <- program.and_then(require(
    has_at_most_one_cursor(request),
    "after and before cannot both be set",
  ))

  program.succeed(Nil)
}

fn require(condition: Bool, message: String) -> program_types.Program(Nil) {
  case condition {
    True -> program.succeed(Nil)
    False -> program.fail(error.ValidationError(message))
  }
}

fn has_at_most_one_cursor(
  request: snippet_dto.ListPublicSnippetsRequest,
) -> Bool {
  case request.after, request.before {
    option.Some(_), option.Some(_) -> False
    _, _ -> True
  }
}

fn paginate_snippets(
  snippets: List(snippet_model.HydratedSnippet),
  request: snippet_dto.ListPublicSnippetsRequest,
) -> #(
  List(snippet_model.HydratedSnippet),
  option.Option(String),
  option.Option(String),
) {
  let direction = page_direction(request)
  let #(page, has_more) = take_page(snippets, request.limit)

  case direction {
    InitialPage ->
      #(page, option.None, maybe_last_slug(page, has_more))
    AfterPage ->
      #(page, maybe_first_slug(page), maybe_last_slug(page, has_more))
    BeforePage ->
      #(
        page,
        maybe_first_slug_when(page, has_more),
        maybe_last_slug(page, True),
      )
  }
}

fn take_page(
  snippets: List(snippet_model.HydratedSnippet),
  limit: Int,
) -> #(List(snippet_model.HydratedSnippet), Bool) {
  take_page_loop(snippets, limit, [])
}

fn take_page_loop(
  snippets: List(snippet_model.HydratedSnippet),
  remaining: Int,
  acc: List(snippet_model.HydratedSnippet),
) -> #(List(snippet_model.HydratedSnippet), Bool) {
  case snippets {
    [] -> #(list.reverse(acc), False)
    [snippet, ..rest] ->
      case remaining > 0 {
        True ->
          take_page_loop(
            rest,
            remaining - 1,
            [snippet, ..acc],
          )
        False -> #(list.reverse(acc), True)
      }
  }
}

fn page_direction(
  request: snippet_dto.ListPublicSnippetsRequest,
) -> PageDirection {
  case request.after, request.before {
    _, option.Some(_) -> BeforePage
    option.Some(_), option.None -> AfterPage
    option.None, option.None -> InitialPage
  }
}

fn maybe_first_slug(
  snippets: List(snippet_model.HydratedSnippet),
) -> option.Option(String) {
  maybe_first_slug_when(snippets, True)
}

fn maybe_first_slug_when(
  snippets: List(snippet_model.HydratedSnippet),
  when: Bool,
) -> option.Option(String) {
  case when, snippets {
    True, [snippet, ..] -> option.Some(snippet.identity.slug)
    _, _ -> option.None
  }
}

fn maybe_last_slug(
  snippets: List(snippet_model.HydratedSnippet),
  when: Bool,
) -> option.Option(String) {
  case when, list.reverse(snippets) {
    True, [snippet, ..] -> option.Some(snippet.identity.slug)
    _, _ -> option.None
  }
}
