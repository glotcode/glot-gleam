import gleam/dynamic
import gleam/option
import gleam/result
import gleam/string
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/user_dto
import glot_core/admin_action
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/auth/user_model

pub fn update_user(
  ctx: context.Context,
  request: user_dto.UpdateUserRequest,
) -> program_types.Program(user_dto.UpdateUserResponse) {
  let username = string.trim(request.username)
  let account_state_reason =
    normalized_account_state_reason(
      request.account_state,
      request.account_state_reason,
    )

  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.UpdateAdminUserAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use hydrated_user <- program.and_then(
    auth_effect.get_user_by_id(request.id)
    |> program.require(error.NotFoundError("user_not_found", "User not found")),
  )
  use _ <- program.and_then(
    user_model.validate_username(username)
    |> result.map_error(error.ValidationError)
    |> program.from_result,
  )

  let user =
    hydrated_user.identity
    |> user_model.change_username(username, ctx.timestamp)
    |> user_model.change_role(request.role, ctx.timestamp)

  let account =
    hydrated_user.account.identity
    |> account_model.change_state(
      request.account_state,
      account_state_reason,
      ctx.timestamp,
    )
    |> account_model.change_tier(request.account_tier, ctx.timestamp)

  use _ <- program.and_then(
    transaction_effect.run_all([
      auth_effect.update_user_tx(user),
      auth_effect.update_account_tx(account),
      user_action_effect.create_user_action_tx(user_action),
    ]),
  )

  program.succeed(
    user_dto.from_updated_user(user_model.HydratedUser(
      identity: user,
      account: account_model.HydratedAccount(
        identity: account,
        delete_scheduled_at: hydrated_user.account.delete_scheduled_at,
      ),
    )),
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(user_dto.UpdateUserRequest) {
  program.decode_dynamic(data, user_dto.update_request_decoder())
}

fn normalized_account_state_reason(
  account_state: account_model.AccountState,
  value: option.Option(String),
) -> option.Option(String) {
  case account_state {
    account_model.Active -> option.None
    account_model.ReadOnly | account_model.Suspended ->
      value
      |> option.map(string.trim)
      |> option.then(fn(reason) {
        case reason == "" {
          True -> option.None
          False -> option.Some(reason)
        }
      })
  }
}
