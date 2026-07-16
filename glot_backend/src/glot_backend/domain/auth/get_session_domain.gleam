import gleam/option
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_backend/request_context
import glot_core/api_action
import glot_core/auth/session_dto
import glot_core/public_action

pub fn get_session(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(option.Option(session_dto.SessionResponse)) {
  use maybe_session <- program.and_then(session_domain.get_session(request_ctx))
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
    request_ctx: request_ctx,
    action: api_action.public(public_action.GetSessionAction),
    actor: actor,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  maybe_session
  |> option.map(session_dto.from_session)
  |> program.succeed
}
