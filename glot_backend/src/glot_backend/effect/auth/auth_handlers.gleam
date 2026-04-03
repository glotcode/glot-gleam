import gleam/option
import gleam/regexp.{type Regexp}
import gleam/result
import gleam/string
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/sql
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/uuid_helpers
import pog
import youid/uuid.{type Uuid}

pub type AuthHandlers {
  AuthHandlers(
    get_user_by_email: fn(Regexp, email_address_model.EmailAddress) ->
      Result(option.Option(user_model.User), error.DbQueryError),
    list_login_tokens_by_user: fn(Uuid, Int) ->
      Result(List(login_token_model.LoginToken), error.DbQueryError),
    get_session_by_token: fn(Regexp, String) ->
      Result(option.Option(session_model.HydratedSession), error.DbQueryError),
    create_user: fn(user_model.User) -> Result(Nil, error.DbCommandError),
    create_session: fn(session_model.Session) -> Result(Nil, error.DbCommandError),
    create_login_token: fn(login_token_model.LoginToken) -> Result(Nil, error.DbCommandError),
    update_login_token: fn(login_token_model.LoginToken) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> AuthHandlers {
  AuthHandlers(
    get_user_by_email: fn(is_email, email) { get_user_by_email(db, is_email, email) },
    list_login_tokens_by_user: fn(user_id, limit) { list_login_tokens_by_user(db, user_id, limit) },
    get_session_by_token: fn(is_email, token) {
      get_session_by_token(db, is_email, token)
    },
    create_user: fn(user) { create_user(db, user) },
    create_session: fn(session) {
      create_session(db, session)
    },
    create_login_token: fn(login_token) {
      create_login_token(db, login_token)
    },
    update_login_token: fn(login_token) {
      update_login_token(db, login_token)
    },
  )
}

pub fn get_user_by_email(
  db: pog.Connection,
  is_email: Regexp,
  user_email: email_address_model.EmailAddress,
) -> Result(option.Option(user_model.User), error.DbQueryError) {
  db_helpers.query(
    db,
    sql.get_user_by_email(email_address_model.to_string(user_email)),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { user_from_rows(is_email, returned.rows) })
}

pub fn list_login_tokens_by_user(
  db: pog.Connection,
  user_id: Uuid,
  limit: Int,
) -> Result(List(login_token_model.LoginToken), error.DbQueryError) {
  db_helpers.query(
    db,
    sql.list_login_tokens_by_user(uuid.to_bit_array(user_id), limit),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { login_tokens_from_rows(returned.rows) })
}

pub fn get_session_by_token(
  db: pog.Connection,
  is_email: Regexp,
  token: String,
) -> Result(option.Option(session_model.HydratedSession), error.DbQueryError) {
  db_helpers.query(db, sql.get_session_by_token(token), fn(err) {
    error.DbQueryError(string.inspect(err))
  })
  |> result.try(fn(returned) { session_from_rows(is_email, returned.rows) })
}

pub fn create_user(
  db: pog.Connection,
  user: user_model.User,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_user(
      uuid.to_bit_array(user.id),
      email_address_model.to_string(user.email),
      user.created_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn create_login_token(
  db: pog.Connection,
  login_token: login_token_model.LoginToken,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_login_token(
      id: uuid.to_bit_array(login_token.id),
      user_id: uuid.to_bit_array(login_token.user_id),
      token: login_token.token,
      created_at: login_token.created_at,
      used_at: login_token.used_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn create_session(
  db: pog.Connection,
  session: session_model.Session,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_session(
      id: uuid.to_bit_array(session.id),
      user_id: uuid.to_bit_array(session.user_id),
      token: session.token,
      ip: session.ip,
      user_agent: session.user_agent,
      created_at: session.created_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update_login_token(
  db: pog.Connection,
  login_token: login_token_model.LoginToken,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_login_token(
      user_id: uuid.to_bit_array(login_token.user_id),
      token: login_token.token,
      created_at: login_token.created_at,
      used_at: login_token.used_at,
      id: uuid.to_bit_array(login_token.id),
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn user_from_rows(
  is_email: Regexp,
  rows: List(sql.GetUserByEmail),
) -> Result(option.Option(user_model.User), error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> user_from_row(is_email, first) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one user row"))
  }
}

fn user_from_row(
  is_email: Regexp,
  row: sql.GetUserByEmail,
) -> Result(user_model.User, error.DbQueryError) {
  case email_address_model.from_string(is_email, row.email) {
    option.Some(valid_email) ->
      Ok(user_model.User(
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
) -> Result(List(login_token_model.LoginToken), error.DbQueryError) {
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
) -> Result(login_token_model.LoginToken, error.DbQueryError) {
  Ok(login_token_model.LoginToken(
    id: uuid_helpers.from_bit_array(row.id),
    user_id: uuid_helpers.from_bit_array(row.user_id),
    token: row.token,
    created_at: row.created_at,
    used_at: row.used_at,
  ))
}

fn session_from_rows(
  is_email: Regexp,
  rows: List(sql.GetSessionByToken),
) -> Result(option.Option(session_model.HydratedSession), error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> session_from_row(is_email, first) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one session row"))
  }
}

fn session_from_row(
  is_email: Regexp,
  row: sql.GetSessionByToken,
) -> Result(session_model.HydratedSession, error.DbQueryError) {
  case email_address_model.from_string(is_email, row.user_email) {
    option.Some(valid_email) ->
      Ok(session_model.HydratedSession(
        id: uuid_helpers.from_bit_array(row.id),
        user: user_model.User(
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
