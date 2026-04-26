import gleam/dynamic
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/domain/shared/snippet_list_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/snippet/snippet_dto

pub fn list_session_snippets(
  ctx: context.Context,
  request: snippet_dto.ListSessionSnippetsRequest,
) -> program_types.Program(snippet_dto.ListPublicSnippetsResponse) {
  use _ <- program.and_then(snippet_list_domain.validate_page_request(
    after: request.after,
    before: request.before,
    limit: request.limit,
  ))
  use session <- program.and_then(session_domain.require_session(ctx))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.identity.id),
        log.uuid("user_id", session.user.identity.id),
      ]),
    ),
  )

  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.ListSessionSnippetsAction,
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
    ),
  ))

  use snippets <- program.and_then(snippet_effect.list(
    visibilities: [],
    usernames: [],
    user_ids: [session.user.identity.id],
    skip_user_ids: [],
    after_slug: request.after,
    before_slug: request.before,
    limit: request.limit + 1,
  ))

  let #(page, previous_cursor, next_cursor) =
    snippet_list_domain.paginate_snippets(
      snippets,
      after: request.after,
      before: request.before,
      limit: request.limit,
    )

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(
    snippet_dto.from_public_snippets(page, previous_cursor, next_cursor),
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.ListSessionSnippetsRequest) {
  program.decode_dynamic(data, snippet_dto.list_session_decoder())
}
