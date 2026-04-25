import gleam/option
import glot_backend/context
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/job/job_effect
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/program
import glot_core/email/email_model
import glot_core/job/job_model
pub fn delete_account(
  ctx: context.Context,
  payload: job_model.DeleteAccountJobPayload,
) -> program_types.Program(Nil) {
  use email_job_id <- program.and_then(basic_effect.uuid_v7())

  let send_email_job =
    job_model.send_email_job(
      email_job_id,
      option.Some(ctx.request_id),
      ctx.timestamp,
      email_model.account_deleted_email(payload.email),
    )

  transaction_effect.run_all([
    auth_effect.delete_sessions_by_account_id_tx(payload.account_id),
    snippet_effect.delete_by_account_id_tx(payload.account_id),
    auth_effect.delete_users_by_account_id_tx(payload.account_id),
    auth_effect.delete_account_tx(payload.account_id),
    job_effect.create_job_tx(send_email_job),
  ])
}

pub fn payload_from_json(
  json_str: String,
) -> program_types.Program(job_model.DeleteAccountJobPayload) {
  use payload <- program.and_then(
    program.parse_json(json_str, job_model.delete_account_job_payload_decoder()),
  )
  program.succeed(payload)
}
