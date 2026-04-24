import gleam/option
import glot_backend/context
import glot_backend/domain/shared/rate_limit_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/auth/session_dto

pub fn get_session(
  ctx: context.Context,
) -> program_types.Program(option.Option(session_dto.SessionResponse)) {
  use maybe_session <- program.and_then(session_domain.get_session(ctx))
  let maybe_session_id = option.map(maybe_session, fn(session) { session.id })
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

  use user_action <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: maybe_user_id,
    action: api_action.GetSessionAction,
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  maybe_session
  |> option.map(session_dto.from_session)
  |> program.succeed
}
