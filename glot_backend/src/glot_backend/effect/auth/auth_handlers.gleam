import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/context
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/sql
import glot_core/auth as auth_core
import glot_core/email
import glot_core/user
import glot_core/uuid_helpers
import pog
import youid/uuid.{type Uuid}

pub fn get_user_by_email(
  ctx: context.Context,
  user_email: email.Email,
) -> Result(option.Option(user.User), error.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.get_user_by_email(email.to_string(user_email)),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { user_from_rows(ctx, returned.rows) })
}

pub fn list_login_tokens_by_user(
  ctx: context.Context,
  user_id: Uuid,
  limit: Int,
) -> Result(List(auth_core.LoginToken), error.DbQueryError) {
  db_helpers.query(
    ctx.db,
    sql.list_login_tokens_by_user(uuid.to_bit_array(user_id), limit),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { login_tokens_from_rows(returned.rows) })
}

pub fn get_session_by_token(
  ctx: context.Context,
  token: String,
) -> Result(option.Option(auth_core.Session), error.DbQueryError) {
  db_helpers.query(ctx.db, sql.get_session_by_token(token), fn(err) {
    error.DbQueryError(string.inspect(err))
  })
  |> result.try(fn(returned) { session_from_rows(ctx, returned.rows) })
}

pub fn insert_user(
  db: pog.Connection,
  id: Uuid,
  email: String,
  created_at: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_user(uuid.to_bit_array(id), email, created_at),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn insert_login_token(
  db: pog.Connection,
  id: Uuid,
  user_id: Uuid,
  token: String,
  created_at: Timestamp,
  used_at: option.Option(Timestamp),
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_login_token(
      id: uuid.to_bit_array(id),
      user_id: uuid.to_bit_array(user_id),
      token: token,
      created_at: created_at,
      used_at: used_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn insert_session(
  db: pog.Connection,
  id: Uuid,
  user_id: Uuid,
  token: String,
  ip: option.Option(String),
  user_agent: option.Option(String),
  created_at: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_session(
      id: uuid.to_bit_array(id),
      user_id: uuid.to_bit_array(user_id),
      token: token,
      ip: ip,
      user_agent: user_agent,
      created_at: created_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update_login_token(
  db: pog.Connection,
  user_id: Uuid,
  token: String,
  created_at: Timestamp,
  used_at: option.Option(Timestamp),
  id: Uuid,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_login_token(
      user_id: uuid.to_bit_array(user_id),
      token: token,
      created_at: created_at,
      used_at: used_at,
      id: uuid.to_bit_array(id),
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn user_from_rows(
  ctx: context.Context,
  rows: List(sql.GetUserByEmail),
) -> Result(option.Option(user.User), error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> user_from_row(ctx, first) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one user row"))
  }
}

fn user_from_row(
  ctx: context.Context,
  row: sql.GetUserByEmail,
) -> Result(user.User, error.DbQueryError) {
  case email.from_string(ctx.regexes.is_email, row.email) {
    option.Some(valid_email) ->
      Ok(user.User(
        id: uuid_helpers.from_bit_array(row.id),
        email: valid_email,
        created_at: row.created_at,
      ))
    option.None ->
      Error(error.DbQueryError(
        "Invalid email format in user row: " <> row.email,
      ))
  }
}

fn login_tokens_from_rows(
  rows: List(sql.ListLoginTokensByUser),
) -> Result(List(auth_core.LoginToken), error.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use token <- result.try(login_token_from_row(first))
      use tokens <- result.try(login_tokens_from_rows(rest))
      Ok([token, ..tokens])
    }
  }
}

fn login_token_from_row(
  row: sql.ListLoginTokensByUser,
) -> Result(auth_core.LoginToken, error.DbQueryError) {
  Ok(auth_core.LoginToken(
    id: uuid_helpers.from_bit_array(row.id),
    user_id: uuid_helpers.from_bit_array(row.user_id),
    token: row.token,
    created_at: row.created_at,
    used_at: row.used_at,
  ))
}

fn session_from_rows(
  ctx: context.Context,
  rows: List(sql.GetSessionByToken),
) -> Result(option.Option(auth_core.Session), error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> session_from_row(ctx, first) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one session row"))
  }
}

fn session_from_row(
  ctx: context.Context,
  row: sql.GetSessionByToken,
) -> Result(auth_core.Session, error.DbQueryError) {
  case email.from_string(ctx.regexes.is_email, row.user_email) {
    option.Some(valid_email) ->
      Ok(auth_core.Session(
        id: uuid_helpers.from_bit_array(row.id),
        user: user.User(
          id: uuid_helpers.from_bit_array(row.user_id),
          email: valid_email,
          created_at: row.user_created_at,
        ),
        token: row.token,
        ip: row.ip,
        user_agent: row.user_agent,
        created_at: row.created_at,
      ))
    option.None ->
      Error(error.DbQueryError(
        "Invalid email format in session row: " <> row.user_email,
      ))
  }
}
