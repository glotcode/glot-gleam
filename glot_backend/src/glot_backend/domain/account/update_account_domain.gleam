import gleam/dynamic
import gleam/result
import gleam/string
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/public_action
import glot_core/auth/account_dto
import glot_core/auth/account_model
import glot_core/auth/user_model

pub fn update_account(
  ctx: context.Context,
  request: account_dto.UpdateAccountRequest,
) -> program_types.Program(account_dto.AccountResponse) {
  use session <- program.and_then(session_domain.require_session(ctx))
  let username = string.trim(request.username)

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
    action: api_action.public(public_action.UpdateAccountAction),
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))

  use _ <- program.and_then(
    user_model.validate_username(username)
    |> result.map_error(error.ValidationError)
    |> program.from_result,
  )

  let user =
    user_model.change_username(session.user.identity, username, ctx.timestamp)

  use _ <- program.and_then(
    transaction_effect.run_all([
      auth_effect.update_user_tx(user),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )

  program.succeed(
    account_dto.from_hydrated_user(user_model.HydratedUser(
      identity: user,
      account: account_model.HydratedAccount(
        identity: session.user.account.identity,
        delete_scheduled_at: session.user.account.delete_scheduled_at,
      ),
    )),
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(account_dto.UpdateAccountRequest) {
  program.decode_dynamic(data, account_dto.update_decoder())
}
