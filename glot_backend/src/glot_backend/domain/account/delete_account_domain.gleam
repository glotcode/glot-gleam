import gleam/dict
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/email_template/email_template_effect
import glot_backend/effect/error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction/transaction_effect
import glot_backend/email_template
import glot_core/job/job_model

pub fn delete_account(
  ctx: context.Context,
  payload: job_model.DeleteAccountJobPayload,
) -> program_types.Program(Nil) {
  use email_job_id <- program.and_then(basic_effect.uuid_v7())
  use template <- program.and_then(program.require(
    email_template_effect.get_email_template_by_name(
      email_template.AccountDeletedTemplate,
    ),
    error.SendEmailError(error.InternalSendEmailError(
      "Missing email template: "
      <> email_template.to_db_name(email_template.AccountDeletedTemplate),
    )),
  ))
  use account_deleted_email <- program.and_then(program.from_result(
    email_template.render_email_template(template, payload.email, dict.new())
    |> result.map_error(fn(message) {
      error.SendEmailError(error.InternalSendEmailError(message))
    }),
  ))

  let send_email_job =
    job_model.send_email_job(
      email_job_id,
      option.Some(ctx.request_id),
      ctx.timestamp,
      account_deleted_email,
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
  use payload <- program.and_then(program.parse_json(
    json_str,
    job_model.delete_account_job_payload_decoder(),
  ))
  program.succeed(payload)
}
