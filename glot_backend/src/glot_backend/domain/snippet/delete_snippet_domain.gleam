import gleam/dynamic
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/authorization_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/snippet/snippet_dto

pub fn delete_snippet(
  ctx: context.Context,
  request: snippet_dto.DeleteSnippetRequest,
) -> program_types.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.identity.id),
        log.uuid("user_id", session.user.identity.id),
        log.string("slug", request.slug),
      ]),
    ),
  )

  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(api_action.DeleteSnippetAction),
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))

  use existing_snippet <- program.and_then(
    snippet_effect.get_by_slug(request.slug)
    |> program.require(error.NotFoundError(
      "snippet_not_found",
      "Snippet not found",
    )),
  )

  use _ <- program.and_then(authorization_domain.require_owner(
    session.user.identity.id,
    existing_snippet.user.id,
  ))

  use _ <- program.and_then(
    transaction_effect.run_all([
      snippet_effect.delete_tx(existing_snippet.identity.id),
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
