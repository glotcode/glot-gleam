import gleam/option
import glot_backend/context
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/domain/shared/session_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/job/job_model

pub fn cancel_delete_account(ctx: context.Context) -> program_types.Program(Nil) {
  use session <- program.and_then(session_domain.require_session(ctx))

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("session_id", session.identity.id),
        log.uuid("user_id", session.user.identity.id),
        log.uuid("account_id", session.user.account.identity.id),
      ]),
    ),
  )

  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.CancelDeleteAccountAction,
    actor: api_action_policy_domain.KnownUser(
      user_id: session.user.identity.id,
      account_state: session.user.account.identity.account_state,
    ),
  ))

  use delete_job_id <- program.and_then(program.from_option(
    session.user.account.identity.delete_job_id,
    error.ConflictError(
      "account_delete_not_scheduled",
      "Account deletion is not scheduled",
    ),
  ))
  use maybe_job <- program.and_then(job_effect.get_job_by_id(delete_job_id))

  let updated_account =
    account_model.set_delete_job_id(
      session.user.account.identity,
      option.None,
      ctx.timestamp,
    )

  case maybe_job {
    option.Some(job)
      if job.job_type == job_model.DeleteAccountJob
      && job.status == job_model.Pending
    ->
      transaction_effect.run_all([
        job_effect.delete_job_tx(delete_job_id),
        auth_effect.update_account_tx(updated_account),
        user_action_effect.create_user_action_tx(user_action),
      ])
    _ ->
      transaction_effect.run_all([
        auth_effect.update_account_tx(updated_account),
        user_action_effect.create_user_action_tx(user_action),
      ])
  }
}
