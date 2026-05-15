import gleam/dynamic
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

pub fn get_snippet(
  ctx: context.Context,
  request: snippet_dto.GetSnippetRequest,
) -> program_types.Program(snippet_dto.SnippetResponse) {
  use maybe_session <- program.and_then(session_domain.get_session(ctx))
  let maybe_session_id = option.map(maybe_session, fn(s) { s.identity.id })
  let maybe_user_id = option.map(maybe_session, fn(s) { s.user.identity.id })

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.string("slug", request.slug),
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
    action: api_action.public(api_action.GetSnippetAction),
    actor: actor,
  ))

  use snippet <- program.and_then(
    snippet_effect.get_by_slug(request.slug)
    |> program.require(error.NotFoundError(
      "snippet_not_found",
      "Snippet not found",
    )),
  )

  let is_owner = maybe_user_id == option.Some(snippet.user.id)

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.string(
          "visibility",
          snippet_model.visibility_to_string(snippet.identity.visibility),
        ),
        log.bool("is_owner", is_owner),
      ]),
    ),
  )

  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  program.succeed(snippet_dto.from_snippet(snippet))
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(snippet_dto.GetSnippetRequest) {
  program.decode_dynamic(data, snippet_dto.get_decoder())
}
