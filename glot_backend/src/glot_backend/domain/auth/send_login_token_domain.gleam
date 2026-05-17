import gleam/dict
import gleam/dynamic
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/crypto_token
import glot_backend/domain/job/job_type_policy_domain
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/dynamic_config
import glot_backend/effect/app_config/app_config_effect
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/email_template/email_template_effect
import glot_backend/effect/error
import glot_backend/effect/error/infra_error
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/user_action/user_action_effect
import glot_backend/email_template
import glot_backend/log
import glot_core/api_action
import glot_core/auth/login_token_dto
import glot_core/auth/login_token_model
import glot_core/email/email_address_model
import glot_core/email/email_model
import glot_core/job/job_model
import glot_core/public_action

pub fn send_login_token(
  ctx: context.Context,
  request: login_token_dto.LoginTokenRequest,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.email("email", request.email))),
  )

  use maybe_user <- program.and_then(auth_effect.get_user_by_email(
    request.email,
  ))
  use user_action <- program.and_then(api_action_policy_domain.enforce(
    ctx: ctx,
    action: api_action.public(public_action.SendLoginTokenAction),
    actor: api_action_policy_domain.actor_from_user(maybe_user),
  ))

  use token <- program.and_then(basic_effect.new_token(10, crypto_token.Numeric))
  use login_token_id <- program.and_then(basic_effect.uuid_v7())
  use job_id <- program.and_then(basic_effect.uuid_v7())

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("login_token_id", login_token_id),
        log.uuid("job_id", job_id),
      ]),
    ),
  )

  use maybe_template <- program.and_then(
    email_template_effect.get_email_template_by_name(
      email_template.LoginTokenTemplate,
    ),
  )
  use sender <- program.and_then(sender_from_config(ctx))
  let assert_template = case maybe_template {
    option.Some(template) -> Ok(template)
    option.None ->
      Error(
        infra_error.EmailTemplateMissing(email_template.to_db_name(
          email_template.LoginTokenTemplate,
        )),
      )
  }
  use template <- program.and_then(log_send_email_internal_error(
    assert_template,
  ))
  use login_email <- program.and_then(
    email_template.render_email_template(
      template,
      sender,
      request.email,
      dict.from_list([#("token", token)]),
    )
    |> result.map_error(infra_error.EmailTemplateRenderFailed)
    |> log_send_email_internal_error,
  )
  use send_email_policy <- program.and_then(
    job_type_policy_domain.require_job_type_policy(job_model.SendEmailJob),
  )

  let send_email_job =
    job_model.send_email_job(
      job_id,
      option.Some(ctx.request_id),
      ctx.timestamp,
      login_email,
      send_email_policy,
    )

  let login_token =
    login_token_model.LoginToken(
      id: login_token_id,
      email: request.email,
      token: token,
      created_at: ctx.timestamp,
      used_at: option.None,
    )

  transaction_effect.run_all([
    auth_effect.create_login_token_tx(login_token),
    job_effect.create_job_tx(send_email_job),
    user_action_effect.create_user_action_tx(user_action),
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
    |> option.to_result(infra_error.EmailDeliveryFailed(
      "invalid_sender_address",
    )),
  ))

  program.succeed(email_model.EmailSender(
    address: address,
    name: email_config.from_name,
  ))
}

pub fn request_from_dynamic(
  ctx: context.Context,
  data: dynamic.Dynamic,
) -> program_types.Program(login_token_dto.LoginTokenRequest) {
  program.decode_dynamic(data, login_token_dto.decoder(ctx.regexes.is_email))
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
