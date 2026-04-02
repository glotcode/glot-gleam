import gleam/dynamic
import gleam/option
import glot_backend/api_action
import glot_backend/context
import glot_backend/domain/generic/rate_limit_domain
import glot_backend/effect/auth/auth_effect
import glot_backend/effect/core/core_effect
import glot_backend/effect/job/job_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_backend/effect/transaction_effect
import glot_backend/email_message
import glot_backend/job
import glot_backend/log
import glot_core/auth
import glot_core/email
import glot_core/user

pub fn send_login_token(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program_types.Program(Nil) {
  use request <- program.and_then(program.decode_json(
    json_body,
    auth.login_token_request_decoder(ctx.regexes.is_email),
  ))

  use _ <- program.and_then(
    core_effect.info(log.singleton(log.email("email", request.email))),
  )

  use user_action_cmd <- program.and_then(rate_limit_domain.enforce(
    ctx: ctx,
    user_id: option.None,
    action: api_action.SendLoginTokenAction,
  ))

  use #(user, maybe_insert_user_cmd) <- program.and_then(find_or_create_user(
    ctx,
    request.email,
  ))
  use token <- program.and_then(core_effect.new_token(10))
  use login_token_id <- program.and_then(core_effect.uuid_v7())
  use job_id <- program.and_then(core_effect.uuid_v7())

  use _ <- program.and_then(
    core_effect.info(
      log.from_list([
        log.string("token", token),
        log.uuid("user_id", user.id),
        log.bool("is_new_user", option.is_some(maybe_insert_user_cmd)),
        log.uuid("job_id", job_id),
      ]),
    ),
  )

  let email_msg = email_message.login_token_message(request.email, token)
  let send_email_job = job.send_email_job(job_id, ctx.timestamp, email_msg)
  let insert_token_cmd =
    auth_effect.insert_login_token(
      id: login_token_id,
      user_id: user.id,
      token: token,
      created_at: ctx.timestamp,
      used_at: option.None,
    )

  transaction_effect.run_all(
    [
      maybe_insert_user_cmd,
      option.Some(insert_token_cmd),
      option.Some(job_effect.create_job(send_email_job)),
      option.Some(user_action_cmd),
    ]
    |> option.values,
  )
}

fn find_or_create_user(
  ctx: context.Context,
  user_email: email.Email,
) -> program_types.Program(
  #(user.User, option.Option(program_types.Program(Nil))),
) {
  use maybe_user <- program.and_then(auth_effect.db_get_user_by_email(
    user_email,
  ))

  case maybe_user {
    option.Some(existing_user) -> program.succeed(#(existing_user, option.None))
    option.None -> {
      use user_id <- program.and_then(core_effect.uuid_v7())

      let new_user =
        user.User(id: user_id, email: user_email, created_at: ctx.timestamp)

      let insert_user_cmd =
        auth_effect.insert_user(
          id: new_user.id,
          email: email.to_string(new_user.email),
          created_at: new_user.created_at,
        )

      program.succeed(#(new_user, option.Some(insert_user_cmd)))
    }
  }
}
