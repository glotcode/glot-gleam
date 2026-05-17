import gleam/dict
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/domain/job/job_type_policy_domain
import glot_backend/dynamic_config
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/email_template/email_template_effect
import glot_backend/effect/error
import glot_backend/effect/error/infra_error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_effect
import glot_backend/effect/transaction/transaction_effect
import glot_backend/email_template
import glot_backend/log
import glot_core/email/email_address_model
import glot_core/email/email_model
import glot_core/job/job_model

pub fn delete_account(
  ctx: context.Context,
  payload: job_model.DeleteAccountJobPayload,
) -> program_types.Program(Nil) {
  use email_job_id <- program.and_then(basic_effect.uuid_v7())
  use maybe_template <- program.and_then(
    email_template_effect.get_email_template_by_name(
      email_template.AccountDeletedTemplate,
    ),
  )
  use sender <- program.and_then(sender_from_config(ctx))
  let assert_template = case maybe_template {
    option.Some(template) -> Ok(template)
    option.None ->
      Error(
        infra_error.EmailTemplateMissing(email_template.to_db_name(
          email_template.AccountDeletedTemplate,
        )),
      )
  }
  use template <- program.and_then(log_send_email_internal_error(
    assert_template,
  ))
  use account_deleted_email <- program.and_then(
    email_template.render_email_template(
      template,
      sender,
      payload.email,
      dict.new(),
    )
    |> result.map_error(infra_error.EmailTemplateRenderFailed)
    |> log_send_email_internal_error,
  )
  use send_email_policy <- program.and_then(
    job_type_policy_domain.require_job_type_policy(job_model.SendEmailJob),
  )

  let send_email_job =
    job_model.send_email_job(
      email_job_id,
      option.Some(ctx.request_id),
      ctx.timestamp,
      account_deleted_email,
      send_email_policy,
    )

  transaction_effect.run_all([
    auth_effect.delete_sessions_by_account_id_tx(payload.account_id),
    snippet_effect.delete_by_account_id_tx(payload.account_id),
    auth_effect.delete_users_by_account_id_tx(payload.account_id),
    auth_effect.delete_account_tx(payload.account_id),
    job_effect.create_job_tx(send_email_job),
  ])
}

fn sender_from_config(
  ctx: context.Context,
) -> program_types.Program(email_model.EmailSender) {
  use config <- program.and_then(app_config_effect.get_dynamic_config())
  let email_config = dynamic_config.email_config(config)
  use address <- program.and_then(log_send_email_internal_error(
    email_address_model.from_string(
      ctx.regexes.is_email,
      email_config.from_address,
    )
    |> option.to_result(
      infra_error.EmailDeliveryFailed("invalid_sender_address"),
    ),
  ))

  program.succeed(email_model.EmailSender(
    address: address,
    name: email_config.from_name,
  ))
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

fn log_send_email_internal_error(
  result: Result(a, infra_error.EmailError),
) -> program_types.Program(a) {
  case result {
    Ok(value) -> program.succeed(value)
    Error(email_error) -> {
      use _ <- program.and_then(
        basic_effect.warn(
          log.singleton(
            log.object("send_email_error", [
              log.string(
                "message",
                infra_error.to_string(infra_error.EmailError(email_error)),
              ),
            ]),
          ),
        ),
      )
      program.fail(error.infra(infra_error.EmailError(email_error)))
    }
  }
}
