import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import glot_backend/helpers/db_helpers
import glot_backend/effect/error
import glot_backend/sql
import glot_core/auth/account_model
import glot_core/auth/login_token_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/uuid_helpers
import pog
import youid/uuid
import gleam/time/timestamp.{type Timestamp}

pub type AuthHandlers {
  AuthHandlers(
    get_user_by_email: fn(regexp.Regexp, email_address_model.EmailAddress) ->
      Result(option.Option(user_model.HydratedUser), error.DbQueryError),
    list_login_tokens_by_email: fn(email_address_model.EmailAddress, Int) ->
      Result(List(login_token_model.LoginToken), error.DbQueryError),
    get_session_by_token: fn(regexp.Regexp, String) ->
      Result(option.Option(session_model.HydratedSession), error.DbQueryError),
    create_user: fn(user_model.User) -> Result(Nil, error.DbCommandError),
    create_account: fn(account_model.Account) -> Result(Nil, error.DbCommandError),
    update_account: fn(account_model.Account) -> Result(Nil, error.DbCommandError),
    update_user: fn(user_model.User) -> Result(Nil, error.DbCommandError),
    delete_sessions_by_account_id: fn(uuid.Uuid) ->
      Result(Nil, error.DbCommandError),
    delete_users_by_account_id: fn(uuid.Uuid) -> Result(Nil, error.DbCommandError),
    delete_account: fn(uuid.Uuid) -> Result(Nil, error.DbCommandError),
    create_session: fn(session_model.Session) -> Result(Nil, error.DbCommandError),
    delete_session: fn(uuid.Uuid) -> Result(Nil, error.DbCommandError),
    create_login_token: fn(login_token_model.LoginToken) -> Result(Nil, error.DbCommandError),
    update_login_token: fn(login_token_model.LoginToken) -> Result(Nil, error.DbCommandError),
    delete_login_tokens_before: fn(Timestamp) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> AuthHandlers {
  AuthHandlers(
    get_user_by_email: fn(is_email, email) { get_user_by_email(db, is_email, email) },
    list_login_tokens_by_email: fn(email, limit) {
      list_login_tokens_by_email(db, email, limit)
    },
    get_session_by_token: fn(is_email, token) {
      get_session_by_token(db, is_email, token)
    },
    create_user: fn(user) { create_user(db, user) },
    create_account: fn(account) { create_account(db, account) },
    update_account: fn(account) { update_account(db, account) },
    update_user: fn(user) { update_user(db, user) },
    delete_sessions_by_account_id: fn(account_id) {
      delete_sessions_by_account_id(db, account_id)
    },
    delete_users_by_account_id: fn(account_id) {
      delete_users_by_account_id(db, account_id)
    },
    delete_account: fn(account_id) { delete_account(db, account_id) },
    create_session: fn(session) {
      create_session(db, session)
    },
    delete_session: fn(id) { delete_session(db, id) },
    create_login_token: fn(login_token) {
      create_login_token(db, login_token)
    },
    update_login_token: fn(login_token) {
      update_login_token(db, login_token)
    },
    delete_login_tokens_before: fn(before) {
      delete_login_tokens_before(db, before)
    },
  )
}

pub fn get_user_by_email(
  db: pog.Connection,
  is_email: regexp.Regexp,
  user_email: email_address_model.EmailAddress,
) -> Result(option.Option(user_model.HydratedUser), error.DbQueryError) {
  db_helpers.query(
    db,
    sql.get_user_by_email(email_address_model.to_string(user_email)),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { user_from_rows(is_email, returned.rows) })
}

pub fn list_login_tokens_by_email(
  db: pog.Connection,
  email: email_address_model.EmailAddress,
  limit: Int,
) -> Result(List(login_token_model.LoginToken), error.DbQueryError) {
  db_helpers.query(
    db,
    sql.list_login_tokens_by_email(email_address_model.to_string(email), limit),
    fn(err) { error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { login_tokens_from_rows(returned.rows) })
}

pub fn get_session_by_token(
  db: pog.Connection,
  is_email: regexp.Regexp,
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
      id: uuid.to_bit_array(user.id),
      account_id: uuid.to_bit_array(user.account_id),
      email: email_address_model.to_string(user.email),
      username: user.username,
      role: user_model.role_to_string(user.role),
      last_login_at: user.last_login_at,
      created_at: user.created_at,
      updated_at: user.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn create_account(
  db: pog.Connection,
  account: account_model.Account,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_account(
      id: uuid.to_bit_array(account.id),
      account_state: account_model.account_state_to_string(
        account.account_state,
      ),
      account_state_reason: account.account_state_reason,
      account_tier: account_model.account_tier_to_string(account.account_tier),
      delete_job_id: account.delete_job_id |> option.map(uuid.to_bit_array),
      created_at: account.created_at,
      updated_at: account.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update_account(
  db: pog.Connection,
  account: account_model.Account,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_account(
      id: uuid.to_bit_array(account.id),
      account_state: account_model.account_state_to_string(
        account.account_state,
      ),
      account_state_reason: account.account_state_reason,
      account_tier: account_model.account_tier_to_string(account.account_tier),
      delete_job_id: account.delete_job_id |> option.map(uuid.to_bit_array),
      created_at: account.created_at,
      updated_at: account.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update_user(
  db: pog.Connection,
  user: user_model.User,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_user(
      account_id: uuid.to_bit_array(user.account_id),
      email: email_address_model.to_string(user.email),
      username: user.username,
      role: user_model.role_to_string(user.role),
      last_login_at: user.last_login_at,
      created_at: user.created_at,
      updated_at: user.updated_at,
      id: uuid.to_bit_array(user.id),
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
      email: email_address_model.to_string(login_token.email),
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

pub fn delete_session(
  db: pog.Connection,
  id: uuid.Uuid,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_session(uuid.to_bit_array(id)), to_error)
  |> result.map(fn(_) { Nil })
}

pub fn delete_sessions_by_account_id(
  db: pog.Connection,
  account_id: uuid.Uuid,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_sessions_by_account_id(uuid.to_bit_array(account_id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_users_by_account_id(
  db: pog.Connection,
  account_id: uuid.Uuid,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_users_by_account_id(uuid.to_bit_array(account_id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_account(
  db: pog.Connection,
  account_id: uuid.Uuid,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_account(uuid.to_bit_array(account_id)),
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
      email: email_address_model.to_string(login_token.email),
      token: login_token.token,
      created_at: login_token.created_at,
      used_at: login_token.used_at,
      id: uuid.to_bit_array(login_token.id),
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_login_tokens_before(
  db: pog.Connection,
  before: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_login_tokens_before(before),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn user_from_rows(
  is_email: regexp.Regexp,
  rows: List(sql.GetUserByEmail),
) -> Result(option.Option(user_model.HydratedUser), error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> user_from_row(is_email, first) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one user row"))
  }
}

fn user_from_row(
  is_email: regexp.Regexp,
  row: sql.GetUserByEmail,
) -> Result(user_model.HydratedUser, error.DbQueryError) {
  use valid_email <- result.try(
    email_address_model.from_string(is_email, row.email)
    |> option.to_result(error.DbQueryError(
      "Invalid email format in user row: " <> row.email,
    )),
  )
  use role <- result.try(
    user_model.role_from_string(row.role)
    |> option.to_result(error.DbQueryError("Invalid user role: " <> row.role)),
  )
  use account_state <- result.try(
    account_model.account_state_from_string(row.account_state)
    |> option.to_result(error.DbQueryError(
      "Invalid account state: " <> row.account_state,
    )),
  )
  use account_tier <- result.try(
    account_model.account_tier_from_string(row.account_tier)
    |> option.to_result(error.DbQueryError(
      "Invalid account tier: " <> row.account_tier,
    )),
  )

  Ok(user_model.HydratedUser(
    identity: user_model.User(
      id: uuid_helpers.from_bit_array(row.id),
      account_id: uuid_helpers.from_bit_array(row.account_id),
      email: valid_email,
      username: row.username,
      role: role,
      last_login_at: row.last_login_at,
      created_at: row.created_at,
      updated_at: row.updated_at,
    ),
    account: account_model.HydratedAccount(
      identity: account_model.Account(
        id: uuid_helpers.from_bit_array(row.account_id),
        account_state: account_state,
        account_state_reason: row.account_state_reason,
        account_tier: account_tier,
        delete_job_id: row.delete_job_id |> option.map(uuid_helpers.from_bit_array),
        created_at: row.created_at,
        updated_at: row.updated_at,
      ),
      delete_scheduled_at: row.delete_scheduled_at,
    ),
  ))
}

fn login_tokens_from_rows(
  rows: List(sql.ListLoginTokensByEmail),
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
  row: sql.ListLoginTokensByEmail,
) -> Result(login_token_model.LoginToken, error.DbQueryError) {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)

  case email_address_model.from_string(is_email, row.email) {
    option.Some(valid_email) ->
      Ok(login_token_model.LoginToken(
        id: uuid_helpers.from_bit_array(row.id),
        email: valid_email,
        token: row.token,
        created_at: row.created_at,
        used_at: row.used_at,
      ))
    option.None ->
      Error(error.DbQueryError(
        "Invalid email format in login token row: " <> row.email,
      ))
  }
}

fn session_from_rows(
  is_email: regexp.Regexp,
  rows: List(sql.GetSessionByToken),
) -> Result(option.Option(session_model.HydratedSession), error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> session_from_row(is_email, first) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one session row"))
  }
}

fn session_from_row(
  is_email: regexp.Regexp,
  row: sql.GetSessionByToken,
) -> Result(session_model.HydratedSession, error.DbQueryError) {
  use valid_email <- result.try(
    email_address_model.from_string(is_email, row.user_email)
    |> option.to_result(error.DbQueryError(
      "Invalid email format in session row: " <> row.user_email,
    )),
  )
  use role <- result.try(
    user_model.role_from_string(row.user_role)
    |> option.to_result(error.DbQueryError(
      "Invalid user role: " <> row.user_role,
    )),
  )
  use account_state <- result.try(
    account_model.account_state_from_string(row.user_account_state)
    |> option.to_result(error.DbQueryError(
      "Invalid account state: " <> row.user_account_state,
    )),
  )
  use account_tier <- result.try(
    account_model.account_tier_from_string(row.user_account_tier)
    |> option.to_result(error.DbQueryError(
      "Invalid account tier: " <> row.user_account_tier,
    )),
  )

  Ok(session_model.HydratedSession(
    identity: session_model.Session(
      id: uuid_helpers.from_bit_array(row.id),
      user_id: uuid_helpers.from_bit_array(row.user_id),
      token: row.token,
      ip: row.ip,
      user_agent: row.user_agent,
      created_at: row.created_at,
    ),
    user: user_model.HydratedUser(
      identity: user_model.User(
        id: uuid_helpers.from_bit_array(row.user_id),
        account_id: uuid_helpers.from_bit_array(row.user_account_id),
        email: valid_email,
        username: row.user_username,
        role: role,
        last_login_at: row.user_last_login_at,
        created_at: row.user_created_at,
        updated_at: row.user_updated_at,
      ),
      account: account_model.HydratedAccount(
        identity: account_model.Account(
          id: uuid_helpers.from_bit_array(row.user_account_id),
          account_state: account_state,
          account_state_reason: row.user_account_state_reason,
          account_tier: account_tier,
          delete_job_id:
            row.user_account_delete_job_id |> option.map(uuid_helpers.from_bit_array),
          created_at: row.user_created_at,
          updated_at: row.user_updated_at,
        ),
        delete_scheduled_at: row.user_account_delete_scheduled_at,
      ),
    ),
  ))
}
