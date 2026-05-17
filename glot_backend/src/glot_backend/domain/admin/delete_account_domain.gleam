import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/error
import glot_backend/effect/error/resource_error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/transaction/transaction_program
import glot_backend/effect/user_action/user_action_effect
import glot_core/admin/account_dto
import glot_core/admin_action
import glot_core/api_action

pub fn delete_account(
  ctx: context.Context,
  request: account_dto.DeleteAccountRequest,
) -> program_types.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.admin(admin_action.DeleteAdminAccountAction),
    actor: api_action_policy_domain.actor_from_user(option.Some(session.user)),
  ))
  use hydrated_user <- program.and_then(
    auth_effect.get_user_by_id(request.user_id)
    |> program.require(error.resource(resource_error.UserNotFound)),
  )
  let delete_pending_job =
    hydrated_user.account.identity.delete_job_id
    |> option.map(job_effect.delete_job_tx)
    |> option.unwrap(transaction_program.succeed(Nil))

  transaction_effect.run(
    transaction_program.sequence([
      delete_pending_job,
      user_action_effect.create_user_action_tx(user_action),
      auth_effect.delete_sessions_by_account_id_tx(
        hydrated_user.account.identity.id,
      ),
      snippet_effect.delete_by_account_id_tx(hydrated_user.account.identity.id),
      auth_effect.delete_users_by_account_id_tx(
        hydrated_user.account.identity.id,
      ),
      auth_effect.delete_account_tx(hydrated_user.account.identity.id),
    ]),
  )
}

pub fn request_from_dynamic(
  data: dynamic.Dynamic,
) -> program_types.Program(account_dto.DeleteAccountRequest) {
  program.decode_dynamic(data, account_dto.delete_request_decoder())
}
