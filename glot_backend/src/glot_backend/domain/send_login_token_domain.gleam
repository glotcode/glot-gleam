import gleam/dynamic
import gleam/list
import gleam/option
import gleam/regexp
import glot_backend/context
import glot_backend/program
import glot_backend/sql
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
    action: sql.SendLoginTokenAction,
  ))

  use user <- program.and_then(find_or_create_user(ctx, request.email))
  use token <- program.and_then(program.random_string(10))
  use login_token_id <- program.and_then(program.uuid_v7())

  let commands = [
    program.DbInsertLoginToken(
      id: login_token_id,
      user_id: user.id,
      token: token,
      created_at: ctx.timestamp,
      used_at: option.None,
    ),
  ]

  use _ <- program.and_then(program.run_in_transaction(commands))
  use _ <- program.and_then(program.log_info(
    "Sending login token to " <> email.to_string(user.email) <> ": " <> token,
  ))
  program.succeed(Nil)
}

fn find_or_create_user(
  ctx: context.Context,
  user_email: email.Email,
) -> program.Program(user.User) {
  use rows <- program.and_then(
    program.db_get_user_by_email(email.to_string(user_email)),
  )

  case list.first(rows) |> option.from_result() {
    option.Some(row) -> user_from_row(ctx.regexp.is_email, row)
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

fn user_from_row(
  is_email: regexp.Regexp,
  row: sql.GetUserByEmail,
) -> program.Program(user.User) {
  case email.from_string(is_email, row.email) {
    option.Some(valid_email) ->
      program.succeed(user.User(
        id: row.id,
        email: valid_email,
        created_at: row.created_at,
      ))
    option.None -> program.fail(program.EmailInvalidError(row.email))
  }
}
