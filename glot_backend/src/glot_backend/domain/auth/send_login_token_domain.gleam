import gleam/dynamic
import gleam/dict
import gleam/option
import gleam/result
import glot_backend/context
import glot_backend/crypto_token
import glot_backend/domain/shared/api_action_policy_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/email_template/email_template_effect
import glot_backend/effect/error
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
import glot_core/job/job_model

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
    action: api_action.SendLoginTokenAction,
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

  use template <- program.and_then(program.require(
    email_template_effect.get_email_template_by_name(
      email_template.LoginTokenTemplate,
    ),
    error.SendEmailError(error.InternalSendEmailError(
      "Missing email template: "
      <> email_template.to_db_name(email_template.LoginTokenTemplate),
    )),
  ))
  use login_email <- program.and_then(program.from_result(
    email_template.render_email_template(
      template,
      request.email,
      dict.from_list([#("token", token)]),
    )
    |> result.map_error(fn(message) {
      error.SendEmailError(error.InternalSendEmailError(message))
    }),
  ))

  let send_email_job =
    job_model.send_email_job(
      job_id,
      option.Some(ctx.request_id),
      ctx.timestamp,
      login_email,
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

pub fn request_from_dynamic(
  ctx: context.Context,
  data: dynamic.Dynamic,
) -> program_types.Program(login_token_dto.LoginTokenRequest) {
  program.decode_dynamic(data, login_token_dto.decoder(ctx.regexes.is_email))
}
