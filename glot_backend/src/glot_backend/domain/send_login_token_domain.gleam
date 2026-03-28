import gleam/dynamic
import gleam/option
import glot_backend/api_action
import glot_backend/context
import glot_backend/email_message
import glot_backend/job
import glot_backend/program
import glot_core/auth
import glot_core/email
import glot_core/rate_limit
import glot_core/user

pub fn send_login_token(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> program.Program(Nil) {
  use request <- program.and_then(program.decode_json(
    json_body,
    auth.login_token_request_decoder(ctx.regexp.is_email),
  ))

  use _ <- program.and_then(program.enforce_ip_rate_limit(
    config: rate_limit.Config(time_unit: rate_limit.Daily, max_requests: 10),
    now: ctx.timestamp,
    ip: ctx.client_ip,
    action: api_action.SendLoginTokenAction,
  ))

  use user <- program.and_then(find_or_create_user(ctx, request.email))
  use token <- program.and_then(program.new_token(10))
  use login_token_id <- program.and_then(program.uuid_v7())
  use job_id <- program.and_then(program.uuid_v7())

  let email_msg = email_message.login_token_message(request.email, token)
  let send_email_job = job.send_email_job(job_id, ctx.timestamp, email_msg)

  let commands = [
    program.DbInsertLoginToken(
      id: login_token_id,
      user_id: user.id,
      token: token,
      created_at: ctx.timestamp,
      used_at: option.None,
    ),
    program.DbInsertJob(send_email_job),
  ]

  program.run_in_transaction(commands)
}

fn find_or_create_user(
  ctx: context.Context,
  user_email: email.Email,
) -> program.Program(user.User) {
  use maybe_user <- program.and_then(program.db_get_user_by_email(user_email))

  case maybe_user {
    option.Some(existing_user) -> program.succeed(existing_user)
    option.None -> {
      use user_id <- program.and_then(program.uuid_v7())

      let new_user =
        user.User(id: user_id, email: user_email, created_at: ctx.timestamp)

      use _ <- program.and_then(
        program.run_command(program.DbInsertUser(
          id: new_user.id,
          email: email.to_string(new_user.email),
          created_at: new_user.created_at,
        )),
      )
      program.succeed(new_user)
    }
  }
}
