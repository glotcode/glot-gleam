import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/response_helpers
import glot_backend/sql
import glot_core/auth
import glot_core/email
import glot_core/user
import glot_core/uuid_helpers
import pog
import wisp

pub fn send_login_token_handler(
  ctx: context.Context,
  req: wisp.Request,
) -> wisp.Response {
  use json_body <- wisp.require_json(req)

  case send_login_token(ctx, json_body) {
    Ok(_) -> wisp.no_content()
    Error(DecodeError(errors)) -> {
      let body = response_helpers.error_body_from_decode_errors(errors)
      wisp.json_response(json.to_string(body), 400)
    }
    Error(GetUserError(err)) -> {
      wisp.log_error("Failed to get user: " <> string.inspect(err))
      let body = response_helpers.error_body("Failed to get user")
      wisp.json_response(json.to_string(body), 500)
    }
    Error(InsertUserError(err)) -> {
      wisp.log_error("Failed to save user: " <> string.inspect(err))
      let body = response_helpers.error_body("Failed to save user")
      wisp.json_response(json.to_string(body), 500)
    }
    Error(EmailInvalidError(err)) -> {
      // This should never happen
      let body = response_helpers.error_body("Invalid email: " <> err)
      wisp.json_response(json.to_string(body), 400)
    }
    Error(InsertLoginTokenError(err)) -> {
      wisp.log_error("Failed to save login token: " <> string.inspect(err))
      let body = response_helpers.error_body("Failed to save login token")
      wisp.json_response(json.to_string(body), 500)
    }
    Error(InsertUserActivityError(err)) -> {
      wisp.log_error("Failed to save user activity: " <> string.inspect(err))
      let body = response_helpers.error_body("Failed to save user activity")
      wisp.json_response(json.to_string(body), 500)
    }
  }
}

fn send_login_token(
  ctx: context.Context,
  json_body: dynamic.Dynamic,
) -> Result(Nil, Error) {
  use login_token_request <- result.try(
    decode.run(json_body, auth.login_token_request_decoder(ctx.regexp.is_email))
    |> result.map_error(DecodeError),
  )

  use user <- result.try(find_or_create_user(ctx, login_token_request.email))
  let token = wisp.random_string(10)

  use _ <- result.try(
    sql.insert_login_token(
      ctx.db,
      uuid_helpers.v7(ctx.timestamp),
      user.id,
      token,
      ctx.timestamp,
      ctx.timestamp,
    )
    |> result.map_error(InsertLoginTokenError),
  )

  wisp.log_info(
    "Sending login token to " <> email.to_string(user.email) <> ": " <> token,
  )

  use _ <- result.try(
    sql.insert_user_activity(
      ctx.db,
      uuid_helpers.v7(ctx.timestamp),
      sql.SendLoginTokenAction,
      "ip",
      "session_token_hash",
      ctx.timestamp,
    )
    |> result.map_error(InsertUserActivityError),
  )

  Ok(Nil)
}

fn find_or_create_user(
  ctx: context.Context,
  email: email.Email,
) -> Result(user.User, Error) {
  use res <- result.try(
    sql.get_user_by_email(ctx.db, email.to_string(email))
    |> result.map_error(GetUserError),
  )

  let user = list.first(res.rows) |> option.from_result()

  case user {
    option.Some(u) -> {
      user_from_row(ctx.regexp.is_email, u)
    }

    option.None -> {
      let u = new_user(ctx.timestamp, email)
      sql.insert_user(ctx.db, u.id, email.to_string(u.email), u.created_at)
      |> result.map(fn(_) { u })
      |> result.map_error(InsertUserError)
    }
  }
}

fn new_user(timestamp: Timestamp, email: email.Email) -> user.User {
  user.User(id: uuid_helpers.v7(timestamp), email: email, created_at: timestamp)
}

fn user_from_row(
  is_email: regexp.Regexp,
  row: sql.GetUserByEmailRow,
) -> Result(user.User, Error) {
  use email <- result.try(
    email.from_string(is_email, row.email)
    |> option.to_result(EmailInvalidError(row.email)),
  )
  Ok(user.User(id: row.id, email: email, created_at: row.created_at))
}

type Error {
  DecodeError(List(decode.DecodeError))
  EmailInvalidError(String)
  GetUserError(pog.QueryError)
  InsertUserError(pog.QueryError)
  InsertLoginTokenError(pog.QueryError)
  InsertUserActivityError(pog.QueryError)
}
