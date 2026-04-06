import gleam/dynamic
import gleam/option
import glot_backend/context
import glot_backend/domain/shared/rate_limit_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction/transaction_effect
import glot_backend/effect/transaction/transaction_program
import glot_backend/effect/user_action/user_action_effect
import glot_backend/log
import glot_core/api_action
import glot_core/auth/login_token_dto
import glot_core/auth/login_token_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/email/email_model
import glot_core/job/job_model

pub fn send_login_token(
  ctx: context.Context,
  request: login_token_dto.LoginTokenRequest,
) -> program_types.Program(Nil) {
  use _ <- program.and_then(
    basic_effect.info(log.singleton(log.email("email", request.email))),
  )

  use user_action <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.None,
    action: api_action.SendLoginTokenAction,
  ))

  use user_outcome <- program.and_then(get_or_create_user(ctx, request.email))
  use token <- program.and_then(basic_effect.new_token(10))
  use login_token_id <- program.and_then(basic_effect.uuid_v7())
  use job_id <- program.and_then(basic_effect.uuid_v7())

  use _ <- program.and_then(
    basic_effect.info(
      log.from_list([
        log.uuid("login_token_id", login_token_id),
        log.uuid("user_id", user_outcome.user.id),
        log.bool("is_new_user", user_outcome.is_new_user),
        log.uuid("job_id", job_id),
      ]),
    ),
  )

  let email_message = email_model.login_token_email(request.email, token)
  let send_email_job =
    job_model.send_email_job(
      job_id,
      option.Some(ctx.request_id),
      ctx.timestamp,
      email_message,
    )
  let create_token_effect =
    auth_effect.create_login_token_tx(login_token_model.LoginToken(
      id: login_token_id,
      user_id: user_outcome.user.id,
      token: token,
      created_at: ctx.timestamp,
      used_at: option.None,
    ))

  transaction_effect.run_all([
    user_outcome.effect,
    create_token_effect,
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

type UserOutcome {
  UserOutcome(
    user: user_model.User,
    effect: program_types.TransactionProgram(Nil),
    is_new_user: Bool,
  )
}

fn get_or_create_user(
  ctx: context.Context,
  email: email_address_model.EmailAddress,
) -> program_types.Program(UserOutcome) {
  use maybe_user <- program.and_then(auth_effect.get_user_by_email(email))

  case maybe_user {
    option.Some(existing_user) ->
      program.succeed(UserOutcome(
        user: existing_user,
        is_new_user: False,
        effect: transaction_program.succeed(Nil),
      ))
    option.None -> {
      use user_id <- program.and_then(basic_effect.uuid_v7())

      let user =
        user_model.User(
          id: user_id,
          email: email,
          username: option.None,
          first_login_at: option.None,
          last_login_at: option.None,
          created_at: ctx.timestamp,
          updated_at: ctx.timestamp,
        )

      program.succeed(UserOutcome(
        user: user,
        is_new_user: True,
        effect: auth_effect.create_user_tx(user),
      ))
    }
  }
}
