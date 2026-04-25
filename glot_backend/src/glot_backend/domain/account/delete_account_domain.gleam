import glot_backend/context
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/program
import glot_core/job/job_model
import youid/uuid.{type Uuid}

pub fn delete_account(
  _ctx: context.Context,
  account_id: Uuid,
) -> program_types.Program(Nil) {
  transaction_effect.run_all([
    auth_effect.delete_sessions_by_account_id_tx(account_id),
    snippet_effect.delete_by_account_id_tx(account_id),
    auth_effect.delete_users_by_account_id_tx(account_id),
    auth_effect.delete_account_tx(account_id),
  ])
}

pub fn account_id_from_json(json_str: String) -> program_types.Program(Uuid) {
  use payload <- program.and_then(
    program.parse_json(json_str, job_model.delete_account_job_payload_decoder()),
  )
  program.succeed(payload.account_id)
}
