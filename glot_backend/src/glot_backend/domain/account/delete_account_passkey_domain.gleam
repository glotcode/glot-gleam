import gleam/dynamic
import gleam/list
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/error/auth_error
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_core/api_action
import glot_core/auth/passkey_dto
import glot_core/public_action

pub fn delete_account_passkey(
  ctx: context.Context,
  request: passkey_dto.DeleteAccountPasskeyRequest,
) -> program_types.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(public_action.DeleteAccountPasskeyAction),
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
      account_tier: session.user.account.identity.account_tier,
      role: session.user.identity.role,
    ),
  ))
  use credentials <- program.and_then(
    auth_effect.list_passkey_credentials_by_user_id(session.user.identity.id),
  )
  use credential <- program.and_then(
    credentials
    |> list.find(fn(credential) { credential.id == request.id })
    |> option.from_result()
    |> program.from_option(error.auth(auth_error.NotOwner)),
  )
  use _ <- program.and_then(transaction_effect.run_all([
    auth_effect.delete_passkey_credential_tx(credential.id),
    user_action_effect.create_user_action_tx(user_action),
  ]))

  program.succeed(Nil)
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(passkey_dto.DeleteAccountPasskeyRequest) {
  program.decode_dynamic(data, passkey_dto.delete_account_passkey_request_decoder())
}
