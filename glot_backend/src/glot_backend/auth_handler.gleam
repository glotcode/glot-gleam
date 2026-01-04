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
import glot_backend/db_helpers
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
    Error(err) -> error_to_response(err)
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

  let insert_login_token_query =
    sql.insert_login_token(
      id: uuid_helpers.v7_bit_array(ctx.timestamp),
      user_id: user.id,
      token:,
      created_at: ctx.timestamp,
      used_at: option.None,
    )

  let insert_user_activity_query =
    sql.insert_user_activity(
      uuid_helpers.v7_bit_array(ctx.timestamp),
      sql.SendLoginTokenAction,
      "TODO: ip address",
      option.None,
      ctx.timestamp,
    )

  use _ <- result.try(
    pog.transaction(ctx.db, fn(tx) {
      use _ <- result.try(db_helpers.execute(
        tx,
        insert_login_token_query,
        InsertLoginTokenError,
      ))

      use _ <- result.try(db_helpers.execute(
        tx,
        insert_user_activity_query,
        InsertUserActivityError,
      ))

      Ok(Nil)
    })
    |> result.map_error(TransactionError),
  )

  wisp.log_info(
    "Sending login token to " <> email.to_string(user.email) <> ": " <> token,
  )

  //|> result.map_error(InsertUserActivityError),

  Ok(Nil)
}

fn find_or_create_user(
  ctx: context.Context,
  email: email.Email,
) -> Result(user.User, Error) {
  let get_user_query = sql.get_user_by_email(email.to_string(email))

  use res <- result.try(db_helpers.query(ctx.db, get_user_query, GetUserError))

  let user = list.first(res.rows) |> option.from_result()

  case user {
    option.Some(u) -> {
      user_from_row(ctx.regexp.is_email, u)
    }

    option.None -> {
      let u = new_user(ctx.timestamp, email)
      let insert_user_query =
        sql.insert_user(u.id, email.to_string(u.email), u.created_at)

      db_helpers.execute(ctx.db, insert_user_query, InsertUserError)
      |> result.map(fn(_) { u })
    }
  }
}

fn new_user(timestamp: Timestamp, email: email.Email) -> user.User {
  user.User(
    id: uuid_helpers.v7_bit_array(timestamp),
    email: email,
    created_at: timestamp,
  )
}

fn user_from_row(
  is_email: regexp.Regexp,
  row: sql.GetUserByEmail,
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
  TransactionError(pog.TransactionError(Error))
}

fn error_to_response(err: Error) -> wisp.Response {
  case err {
    DecodeError(errors) -> {
      let body = response_helpers.error_body_from_decode_errors(errors)
      wisp.json_response(json.to_string(body), 400)
    }
    EmailInvalidError(err) -> {
      // This should never happen
      let body = response_helpers.error_body("Invalid email: " <> err)
      wisp.json_response(json.to_string(body), 400)
    }
    GetUserError(err) -> {
      wisp.log_error("Failed to get user: " <> string.inspect(err))
      let body = response_helpers.error_body("Failed to get user")
      wisp.json_response(json.to_string(body), 500)
    }
    InsertUserError(err) -> {
      wisp.log_error("Failed to save user: " <> string.inspect(err))
      let body = response_helpers.error_body("Failed to save user")
      wisp.json_response(json.to_string(body), 500)
    }
    InsertLoginTokenError(err) -> {
      wisp.log_error("Failed to save login token: " <> string.inspect(err))
      let body = response_helpers.error_body("Failed to save login token")
      wisp.json_response(json.to_string(body), 500)
    }
    InsertUserActivityError(err) -> {
      wisp.log_error("Failed to save user activity: " <> string.inspect(err))
      let body = response_helpers.error_body("Failed to save user activity")
      wisp.json_response(json.to_string(body), 500)
    }
    TransactionError(err) -> {
      wisp.log_error("Transaction failed: " <> string.inspect(err))
      let body = response_helpers.error_body("Transaction failed")
      wisp.json_response(json.to_string(body), 500)
    }
  }
}
