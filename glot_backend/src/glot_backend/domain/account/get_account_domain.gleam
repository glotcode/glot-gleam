import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_backend/request_context
import glot_core/api_action
import glot_core/auth/account_dto
import glot_core/public_action

pub fn get_account(
  request_ctx: request_context.RequestContext,
) -> program_types.Program(account_dto.AccountResponse) {
  use session <- program.and_then(session_domain.require_session(request_ctx))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.identity.id),
        log.uuid("user_id", session.user.identity.id),
      ]),
    ),
  )

  use user_action <- program.and_then(api_action_policy_domain.enforce(
    request_ctx: request_ctx,
    action: api_action.public(public_action.GetAccountAction),
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))
  use _ <- program.and_then(user_action_effect.create_user_action(user_action))

  session.user
  |> account_dto.from_hydrated_user
  |> program.succeed
}
