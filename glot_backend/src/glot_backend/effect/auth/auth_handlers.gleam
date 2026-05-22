import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/error/db_error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import glot_core/auth/account_model
import glot_core/auth/login_token_model
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import glot_core/auth/platform_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/uuid_helpers
import glot_core/pagination_model
import youid/uuid

pub type AuthHandlers {
  AuthHandlers(
    get_user_by_email: fn(regexp.Regexp, email_address_model.EmailAddress) ->
      Result(option.Option(user_model.HydratedUser), db_error.DbQueryError),
    get_user_by_id: fn(regexp.Regexp, uuid.Uuid) ->
      Result(option.Option(user_model.HydratedUser), db_error.DbQueryError),
    list_users: fn(
      regexp.Regexp,
      pagination_model.CursorPagination,
      auth_algebra.UserListFilters,
    ) -> Result(List(user_model.HydratedUser), db_error.DbQueryError),
    list_login_tokens_by_email: fn(email_address_model.EmailAddress, Int) ->
      Result(List(login_token_model.LoginToken), db_error.DbQueryError),
    get_passkey_credential_by_credential_id: fn(BitArray) ->
      Result(
        option.Option(passkey_credential_model.PasskeyCredential),
        db_error.DbQueryError,
      ),
    list_passkey_credentials_by_user_id: fn(uuid.Uuid) ->
      Result(List(passkey_credential_model.PasskeyCredential), db_error.DbQueryError),
    get_passkey_challenge_by_id: fn(uuid.Uuid) ->
      Result(
        option.Option(passkey_challenge_model.PasskeyChallenge),
        db_error.DbQueryError,
      ),
    get_session_by_token: fn(regexp.Regexp, String) ->
      Result(
        option.Option(session_model.HydratedSession),
        db_error.DbQueryError,
      ),
    get_session_by_token_for_update: fn(String) ->
      Result(option.Option(session_model.Session), db_error.DbQueryError),
    get_session_by_previous_token: fn(regexp.Regexp, String) ->
      Result(
        option.Option(session_model.HydratedSession),
        db_error.DbQueryError,
      ),
    get_session_by_previous_token_for_update: fn(String) ->
      Result(option.Option(session_model.Session), db_error.DbQueryError),
    create_user: fn(user_model.User) -> Result(Nil, db_error.DbCommandError),
    create_account: fn(account_model.Account) ->
      Result(Nil, db_error.DbCommandError),
    update_account: fn(account_model.Account) ->
      Result(Nil, db_error.DbCommandError),
    update_user: fn(user_model.User) -> Result(Nil, db_error.DbCommandError),
    delete_sessions_by_account_id: fn(uuid.Uuid) ->
      Result(Nil, db_error.DbCommandError),
    delete_users_by_account_id: fn(uuid.Uuid) ->
      Result(Nil, db_error.DbCommandError),
    delete_account: fn(uuid.Uuid) -> Result(Nil, db_error.DbCommandError),
    create_session: fn(session_model.Session) ->
      Result(Nil, db_error.DbCommandError),
    update_session: fn(session_model.Session) ->
      Result(Nil, db_error.DbCommandError),
    delete_session: fn(uuid.Uuid) -> Result(Nil, db_error.DbCommandError),
    create_login_token: fn(login_token_model.LoginToken) ->
      Result(Nil, db_error.DbCommandError),
    create_passkey_credential: fn(passkey_credential_model.PasskeyCredential) ->
      Result(Nil, db_error.DbCommandError),
    create_passkey_challenge: fn(passkey_challenge_model.PasskeyChallenge) ->
      Result(Nil, db_error.DbCommandError),
    delete_passkey_credential: fn(uuid.Uuid) ->
      Result(Nil, db_error.DbCommandError),
    update_login_token: fn(login_token_model.LoginToken) ->
      Result(Nil, db_error.DbCommandError),
    update_passkey_credential: fn(passkey_credential_model.PasskeyCredential) ->
      Result(Nil, db_error.DbCommandError),
    delete_login_tokens_before: fn(Timestamp) ->
      Result(Nil, db_error.DbCommandError),
    delete_passkey_challenge: fn(uuid.Uuid) ->
      Result(Nil, db_error.DbCommandError),
  )
}

pub fn new(db: db_helpers.Db) -> AuthHandlers {
  AuthHandlers(
    get_user_by_email: fn(is_email, email) {
      get_user_by_email(db, is_email, email)
    },
    get_user_by_id: fn(is_email, id) { get_user_by_id(db, is_email, id) },
    list_users: fn(is_email, pagination, filters) {
      list_users(db, is_email, pagination, filters)
    },
    list_login_tokens_by_email: fn(email, limit) {
      list_login_tokens_by_email(db, email, limit)
    },
    get_passkey_credential_by_credential_id: fn(credential_id) {
      get_passkey_credential_by_credential_id(db, credential_id)
    },
    list_passkey_credentials_by_user_id: fn(user_id) {
      list_passkey_credentials_by_user_id(db, user_id)
    },
    get_passkey_challenge_by_id: fn(id) { get_passkey_challenge_by_id(db, id) },
    get_session_by_token: fn(is_email, token) {
      get_session_by_token(db, is_email, token)
    },
    get_session_by_token_for_update: fn(token) {
      get_session_by_token_for_update(db, token)
    },
    get_session_by_previous_token: fn(is_email, token) {
      get_session_by_previous_token(db, is_email, token)
    },
    get_session_by_previous_token_for_update: fn(token) {
      get_session_by_previous_token_for_update(db, token)
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
    create_session: fn(session) { create_session(db, session) },
    update_session: fn(session) { update_session(db, session) },
    delete_session: fn(id) { delete_session(db, id) },
    create_login_token: fn(login_token) { create_login_token(db, login_token) },
    create_passkey_credential: fn(passkey_credential) {
      create_passkey_credential(db, passkey_credential)
    },
    create_passkey_challenge: fn(passkey_challenge) {
      create_passkey_challenge(db, passkey_challenge)
    },
    delete_passkey_credential: fn(id) { delete_passkey_credential(db, id) },
    update_login_token: fn(login_token) { update_login_token(db, login_token) },
    update_passkey_credential: fn(passkey_credential) {
      update_passkey_credential(db, passkey_credential)
    },
    delete_login_tokens_before: fn(before) {
      delete_login_tokens_before(db, before)
    },
    delete_passkey_challenge: fn(id) { delete_passkey_challenge(db, id) },
  )
}

pub fn get_user_by_email(
  db: db_helpers.Db,
  is_email: regexp.Regexp,
  user_email: email_address_model.EmailAddress,
) -> Result(option.Option(user_model.HydratedUser), db_error.DbQueryError) {
  db_helpers.query(
    db,
    sql.get_user_by_email(email_address_model.to_string(user_email)),
    fn(err) { db_error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { user_from_rows(is_email, returned.rows) })
}

pub fn get_user_by_id(
  db: db_helpers.Db,
  is_email: regexp.Regexp,
  id: uuid.Uuid,
) -> Result(option.Option(user_model.HydratedUser), db_error.DbQueryError) {
  db_helpers.query(db, sql.get_user_by_id(uuid.to_bit_array(id)), fn(err) {
    db_error.DbQueryError(string.inspect(err))
  })
  |> result.try(fn(returned) { user_by_id_from_rows(is_email, returned.rows) })
}

pub fn list_users(
  db: db_helpers.Db,
  is_email: regexp.Regexp,
  pagination: pagination_model.CursorPagination,
  filters: auth_algebra.UserListFilters,
) -> Result(List(user_model.HydratedUser), db_error.DbQueryError) {
  let to_error = fn(err) { db_error.DbQueryError(string.inspect(err)) }
  let role = option.map(filters.role, user_model.role_to_string)
  let account_state =
    option.map(filters.account_state, account_model.account_state_to_string)
  let account_tier =
    option.map(filters.account_tier, account_model.account_tier_to_string)

  case pagination {
    pagination_model.InitialPage(limit) ->
      db_helpers.query(
        db,
        sql.list_users_after(
          after_id: option.None,
          email: filters.email,
          username: filters.username,
          id: option.map(filters.id, uuid.to_bit_array),
          role: role,
          account_state: account_state,
          account_tier: account_tier,
          page_limit: limit,
        ),
        to_error,
      )
      |> result.try(fn(returned) {
        list_users_after_rows(is_email, returned.rows)
      })

    pagination_model.AfterPage(cursor, limit) -> {
      use id <- result.try(cursor_to_uuid(cursor))
      db_helpers.query(
        db,
        sql.list_users_after(
          after_id: option.Some(uuid.to_bit_array(id)),
          email: filters.email,
          username: filters.username,
          id: option.map(filters.id, uuid.to_bit_array),
          role: role,
          account_state: account_state,
          account_tier: account_tier,
          page_limit: limit,
        ),
        to_error,
      )
      |> result.try(fn(returned) {
        list_users_after_rows(is_email, returned.rows)
      })
    }

    pagination_model.BeforePage(cursor, limit) -> {
      use id <- result.try(cursor_to_uuid(cursor))
      db_helpers.query(
        db,
        sql.list_users_before(
          before_id: option.Some(uuid.to_bit_array(id)),
          email: filters.email,
          username: filters.username,
          id: option.map(filters.id, uuid.to_bit_array),
          role: role,
          account_state: account_state,
          account_tier: account_tier,
          page_limit: limit,
        ),
        to_error,
      )
      |> result.try(fn(returned) {
        list_users_before_rows(is_email, returned.rows)
      })
    }
  }
}

pub fn list_login_tokens_by_email(
  db: db_helpers.Db,
  email: email_address_model.EmailAddress,
  limit: Int,
) -> Result(List(login_token_model.LoginToken), db_error.DbQueryError) {
  db_helpers.query(
    db,
    sql.list_login_tokens_by_email(email_address_model.to_string(email), limit),
    fn(err) { db_error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { login_tokens_from_rows(returned.rows) })
}

pub fn get_passkey_credential_by_credential_id(
  db: db_helpers.Db,
  credential_id: BitArray,
) -> Result(
  option.Option(passkey_credential_model.PasskeyCredential),
  db_error.DbQueryError,
) {
  db_helpers.query(
    db,
    sql.get_passkey_credential_by_credential_id(credential_id),
    fn(err) { db_error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) {
    passkey_credential_from_lookup_rows(returned.rows)
  })
}

pub fn list_passkey_credentials_by_user_id(
  db: db_helpers.Db,
  user_id: uuid.Uuid,
) -> Result(List(passkey_credential_model.PasskeyCredential), db_error.DbQueryError) {
  db_helpers.query(
    db,
    sql.list_passkey_credentials_by_user_id(uuid.to_bit_array(user_id)),
    fn(err) { db_error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) {
    passkey_credentials_from_rows(returned.rows)
  })
}

pub fn get_passkey_challenge_by_id(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(
  option.Option(passkey_challenge_model.PasskeyChallenge),
  db_error.DbQueryError,
) {
  db_helpers.query(db, sql.get_passkey_challenge_by_id(uuid.to_bit_array(id)), fn(err) {
    db_error.DbQueryError(string.inspect(err))
  })
  |> result.try(fn(returned) { passkey_challenge_from_rows(returned.rows) })
}

pub fn get_session_by_token(
  db: db_helpers.Db,
  is_email: regexp.Regexp,
  token: String,
) -> Result(option.Option(session_model.HydratedSession), db_error.DbQueryError) {
  db_helpers.query(db, sql.get_session_by_token(token), fn(err) {
    db_error.DbQueryError(string.inspect(err))
  })
  |> result.try(fn(returned) { session_from_rows(is_email, returned.rows) })
}

pub fn get_session_by_token_for_update(
  db: db_helpers.Db,
  token: String,
) -> Result(option.Option(session_model.Session), db_error.DbQueryError) {
  db_helpers.query(db, sql.get_session_by_token_for_update(token), fn(err) {
    db_error.DbQueryError(string.inspect(err))
  })
  |> result.try(fn(returned) { session_identity_from_rows(returned.rows) })
}

pub fn get_session_by_previous_token(
  db: db_helpers.Db,
  is_email: regexp.Regexp,
  token: String,
) -> Result(option.Option(session_model.HydratedSession), db_error.DbQueryError) {
  db_helpers.query(
    db,
    sql.get_session_by_previous_token(option.Some(token)),
    fn(err) { db_error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) {
    session_from_previous_rows(is_email, returned.rows)
  })
}

pub fn get_session_by_previous_token_for_update(
  db: db_helpers.Db,
  token: String,
) -> Result(option.Option(session_model.Session), db_error.DbQueryError) {
  db_helpers.query(
    db,
    sql.get_session_by_previous_token_for_update(option.Some(token)),
    fn(err) { db_error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) {
    session_identity_from_previous_rows(returned.rows)
  })
}

pub fn create_user(
  db: db_helpers.Db,
  user: user_model.User,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

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
  db: db_helpers.Db,
  account: account_model.Account,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

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
  db: db_helpers.Db,
  account: account_model.Account,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

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
  db: db_helpers.Db,
  user: user_model.User,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

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
  db: db_helpers.Db,
  login_token: login_token_model.LoginToken,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

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

pub fn create_passkey_credential(
  db: db_helpers.Db,
  passkey_credential: passkey_credential_model.PasskeyCredential,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_passkey_credential(
      id: uuid.to_bit_array(passkey_credential.id),
      user_id: uuid.to_bit_array(passkey_credential.user_id),
      credential_id: passkey_credential.credential_id,
      cose_key: passkey_credential.cose_key,
      sign_count: passkey_credential.sign_count,
      aaguid: passkey_credential.aaguid,
      os_name: option.map(
        passkey_credential.os_name,
        platform_model.operating_system_to_string,
      ),
      browser_name: option.map(
        passkey_credential.browser_name,
        platform_model.browser_to_string,
      ),
      raw_user_agent: passkey_credential.raw_user_agent,
      created_at: passkey_credential.created_at,
      updated_at: passkey_credential.updated_at,
      last_used_at: passkey_credential.last_used_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn create_passkey_challenge(
  db: db_helpers.Db,
  passkey_challenge: passkey_challenge_model.PasskeyChallenge,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_passkey_challenge(
      id: uuid.to_bit_array(passkey_challenge.id),
      user_id: option.map(passkey_challenge.user_id, uuid.to_bit_array),
      flow: passkey_challenge_model.flow_to_string(passkey_challenge.flow),
      challenge_state: passkey_challenge.challenge_state,
      created_at: passkey_challenge.created_at,
      expires_at: passkey_challenge.expires_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn create_session(
  db: db_helpers.Db,
  session: session_model.Session,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_session(
      id: uuid.to_bit_array(session.id),
      user_id: uuid.to_bit_array(session.user_id),
      token: session.token,
      previous_token: session.previous_token,
      previous_token_valid_until: session.previous_token_valid_until,
      ip: session.ip,
      os_name: option.map(
        session.os_name,
        platform_model.operating_system_to_string,
      ),
      browser_name: option.map(
        session.browser_name,
        platform_model.browser_to_string,
      ),
      user_agent: session.user_agent,
      created_at: session.created_at,
      token_updated_at: session.token_updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update_session(
  db: db_helpers.Db,
  session: session_model.Session,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_session(
      user_id: uuid.to_bit_array(session.user_id),
      token: session.token,
      previous_token: session.previous_token,
      previous_token_valid_until: session.previous_token_valid_until,
      ip: session.ip,
      os_name: option.map(
        session.os_name,
        platform_model.operating_system_to_string,
      ),
      browser_name: option.map(
        session.browser_name,
        platform_model.browser_to_string,
      ),
      user_agent: session.user_agent,
      created_at: session.created_at,
      token_updated_at: session.token_updated_at,
      id: uuid.to_bit_array(session.id),
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_session(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_session(uuid.to_bit_array(id)), to_error)
  |> result.map(fn(_) { Nil })
}

pub fn delete_sessions_by_account_id(
  db: db_helpers.Db,
  account_id: uuid.Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_sessions_by_account_id(uuid.to_bit_array(account_id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_users_by_account_id(
  db: db_helpers.Db,
  account_id: uuid.Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_users_by_account_id(uuid.to_bit_array(account_id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_account(
  db: db_helpers.Db,
  account_id: uuid.Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_account(uuid.to_bit_array(account_id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn update_login_token(
  db: db_helpers.Db,
  login_token: login_token_model.LoginToken,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

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

pub fn update_passkey_credential(
  db: db_helpers.Db,
  passkey_credential: passkey_credential_model.PasskeyCredential,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_passkey_credential(
      user_id: uuid.to_bit_array(passkey_credential.user_id),
      credential_id: passkey_credential.credential_id,
      cose_key: passkey_credential.cose_key,
      sign_count: passkey_credential.sign_count,
      aaguid: passkey_credential.aaguid,
      os_name: option.map(
        passkey_credential.os_name,
        platform_model.operating_system_to_string,
      ),
      browser_name: option.map(
        passkey_credential.browser_name,
        platform_model.browser_to_string,
      ),
      raw_user_agent: passkey_credential.raw_user_agent,
      created_at: passkey_credential.created_at,
      updated_at: passkey_credential.updated_at,
      last_used_at: passkey_credential.last_used_at,
      id: uuid.to_bit_array(passkey_credential.id),
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_login_tokens_before(
  db: db_helpers.Db,
  before: Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_login_tokens_before(before), to_error)
  |> result.map(fn(_) { Nil })
}

pub fn delete_passkey_challenge(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_passkey_challenge(uuid.to_bit_array(id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_passkey_credential(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.delete_passkey_credential(uuid.to_bit_array(id)),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn user_from_rows(
  is_email: regexp.Regexp,
  rows: List(sql.GetUserByEmail),
) -> Result(option.Option(user_model.HydratedUser), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> user_from_row(is_email, first) |> result.map(option.Some)
    _ -> Error(db_error.DbQueryError("Expected at most one user row"))
  }
}

fn user_by_id_from_rows(
  is_email: regexp.Regexp,
  rows: List(sql.GetUserById),
) -> Result(option.Option(user_model.HydratedUser), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] ->
      user_from_get_user_by_id_row(is_email, first) |> result.map(option.Some)
    _ -> Error(db_error.DbQueryError("Expected at most one user row"))
  }
}

fn user_from_row(
  is_email: regexp.Regexp,
  row: sql.GetUserByEmail,
) -> Result(user_model.HydratedUser, db_error.DbQueryError) {
  hydrated_user(
    is_email: is_email,
    id: row.id,
    account_id: row.account_id,
    email: row.email,
    username: row.username,
    role: row.role,
    account_state: row.account_state,
    account_state_reason: row.account_state_reason,
    account_tier: row.account_tier,
    delete_job_id: row.delete_job_id,
    delete_scheduled_at: row.delete_scheduled_at,
    last_login_at: row.last_login_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
  )
}

fn user_from_get_user_by_id_row(
  is_email: regexp.Regexp,
  row: sql.GetUserById,
) -> Result(user_model.HydratedUser, db_error.DbQueryError) {
  hydrated_user(
    is_email: is_email,
    id: row.id,
    account_id: row.account_id,
    email: row.email,
    username: row.username,
    role: row.role,
    account_state: row.account_state,
    account_state_reason: row.account_state_reason,
    account_tier: row.account_tier,
    delete_job_id: row.delete_job_id,
    delete_scheduled_at: row.delete_scheduled_at,
    last_login_at: row.last_login_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
  )
}

fn user_from_list_users_after_row(
  is_email: regexp.Regexp,
  row: sql.ListUsersAfter,
) -> Result(user_model.HydratedUser, db_error.DbQueryError) {
  hydrated_user(
    is_email: is_email,
    id: row.id,
    account_id: row.account_id,
    email: row.email,
    username: row.username,
    role: row.role,
    account_state: row.account_state,
    account_state_reason: row.account_state_reason,
    account_tier: row.account_tier,
    delete_job_id: row.delete_job_id,
    delete_scheduled_at: row.delete_scheduled_at,
    last_login_at: row.last_login_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
  )
}

fn user_from_list_users_before_row(
  is_email: regexp.Regexp,
  row: sql.ListUsersBefore,
) -> Result(user_model.HydratedUser, db_error.DbQueryError) {
  hydrated_user(
    is_email: is_email,
    id: row.id,
    account_id: row.account_id,
    email: row.email,
    username: row.username,
    role: row.role,
    account_state: row.account_state,
    account_state_reason: row.account_state_reason,
    account_tier: row.account_tier,
    delete_job_id: row.delete_job_id,
    delete_scheduled_at: row.delete_scheduled_at,
    last_login_at: row.last_login_at,
    created_at: row.created_at,
    updated_at: row.updated_at,
  )
}

fn hydrated_user(
  is_email is_email: regexp.Regexp,
  id id: BitArray,
  account_id account_id: BitArray,
  email email: String,
  username username: String,
  role role: String,
  account_state account_state: String,
  account_state_reason account_state_reason: option.Option(String),
  account_tier account_tier: String,
  delete_job_id delete_job_id: option.Option(BitArray),
  delete_scheduled_at delete_scheduled_at: option.Option(Timestamp),
  last_login_at last_login_at: Timestamp,
  created_at created_at: Timestamp,
  updated_at updated_at: Timestamp,
) -> Result(user_model.HydratedUser, db_error.DbQueryError) {
  use valid_email <- result.try(
    email_address_model.from_string(is_email, email)
    |> option.to_result(db_error.DbQueryError(
      "Invalid email format in user row: " <> email,
    )),
  )
  use role <- result.try(
    user_model.role_from_string(role)
    |> option.to_result(db_error.DbQueryError("Invalid user role: " <> role)),
  )
  use account_state <- result.try(
    account_model.account_state_from_string(account_state)
    |> option.to_result(db_error.DbQueryError(
      "Invalid account state: " <> account_state,
    )),
  )
  use account_tier <- result.try(
    account_model.account_tier_from_string(account_tier)
    |> option.to_result(db_error.DbQueryError(
      "Invalid account tier: " <> account_tier,
    )),
  )

  Ok(user_model.HydratedUser(
    identity: user_model.User(
      id: uuid_helpers.from_bit_array(id),
      account_id: uuid_helpers.from_bit_array(account_id),
      email: valid_email,
      username: username,
      role: role,
      last_login_at: last_login_at,
      created_at: created_at,
      updated_at: updated_at,
    ),
    account: account_model.HydratedAccount(
      identity: account_model.Account(
        id: uuid_helpers.from_bit_array(account_id),
        account_state: account_state,
        account_state_reason: account_state_reason,
        account_tier: account_tier,
        delete_job_id: delete_job_id
          |> option.map(uuid_helpers.from_bit_array),
        created_at: created_at,
        updated_at: updated_at,
      ),
      delete_scheduled_at: delete_scheduled_at,
    ),
  ))
}

fn list_users_after_rows(
  is_email: regexp.Regexp,
  rows: List(sql.ListUsersAfter),
) -> Result(List(user_model.HydratedUser), db_error.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use user <- result.try(user_from_list_users_after_row(is_email, first))
      use users <- result.try(list_users_after_rows(is_email, rest))
      Ok([user, ..users])
    }
  }
}

fn list_users_before_rows(
  is_email: regexp.Regexp,
  rows: List(sql.ListUsersBefore),
) -> Result(List(user_model.HydratedUser), db_error.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use user <- result.try(user_from_list_users_before_row(is_email, first))
      use users <- result.try(list_users_before_rows(is_email, rest))
      Ok([user, ..users])
    }
  }
}

fn cursor_to_uuid(
  cursor: pagination_model.Cursor,
) -> Result(uuid.Uuid, db_error.DbQueryError) {
  cursor
  |> pagination_model.to_string
  |> uuid.from_string
  |> result.map_error(fn(_) { db_error.DbQueryError("Invalid user cursor") })
}

fn login_tokens_from_rows(
  rows: List(sql.ListLoginTokensByEmail),
) -> Result(List(login_token_model.LoginToken), db_error.DbQueryError) {
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
) -> Result(login_token_model.LoginToken, db_error.DbQueryError) {
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
      Error(db_error.DbQueryError(
        "Invalid email format in login token row: " <> row.email,
      ))
  }
}

fn passkey_credential_from_lookup_rows(
  rows: List(sql.GetPasskeyCredentialByCredentialId),
) -> Result(option.Option(passkey_credential_model.PasskeyCredential), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> passkey_credential_from_lookup_row(first) |> result.map(option.Some)
    _ ->
      Error(db_error.DbQueryError(
        "Expected at most one passkey credential row",
      ))
  }
}

fn passkey_credentials_from_rows(
  rows: List(sql.ListPasskeyCredentialsByUserId),
) -> Result(List(passkey_credential_model.PasskeyCredential), db_error.DbQueryError) {
  case rows {
    [] -> Ok([])
    [first, ..rest] -> {
      use credential <- result.try(passkey_credential_from_row(first))
      use credentials <- result.try(passkey_credentials_from_rows(rest))
      Ok([credential, ..credentials])
    }
  }
}

fn passkey_credential_from_lookup_row(
  row: sql.GetPasskeyCredentialByCredentialId,
) -> Result(passkey_credential_model.PasskeyCredential, db_error.DbQueryError) {
  use os_name <- result.try(
    optional_operating_system(row.os_name)
    |> option.to_result(db_error.DbQueryError("Invalid operating system")),
  )
  use browser_name <- result.try(
    optional_browser(row.browser_name)
    |> option.to_result(db_error.DbQueryError("Invalid browser")),
  )
  Ok(passkey_credential_model.PasskeyCredential(
    id: uuid_helpers.from_bit_array(row.id),
    user_id: uuid_helpers.from_bit_array(row.user_id),
    credential_id: row.credential_id,
    cose_key: row.cose_key,
    sign_count: row.sign_count,
    aaguid: row.aaguid,
    os_name: os_name,
    browser_name: browser_name,
    raw_user_agent: row.raw_user_agent,
    created_at: row.created_at,
    updated_at: row.updated_at,
    last_used_at: row.last_used_at,
  ))
}

fn passkey_credential_from_row(
  row: sql.ListPasskeyCredentialsByUserId,
) -> Result(passkey_credential_model.PasskeyCredential, db_error.DbQueryError) {
  use os_name <- result.try(
    optional_operating_system(row.os_name)
    |> option.to_result(db_error.DbQueryError("Invalid operating system")),
  )
  use browser_name <- result.try(
    optional_browser(row.browser_name)
    |> option.to_result(db_error.DbQueryError("Invalid browser")),
  )
  Ok(passkey_credential_model.PasskeyCredential(
    id: uuid_helpers.from_bit_array(row.id),
    user_id: uuid_helpers.from_bit_array(row.user_id),
    credential_id: row.credential_id,
    cose_key: row.cose_key,
    sign_count: row.sign_count,
    aaguid: row.aaguid,
    os_name: os_name,
    browser_name: browser_name,
    raw_user_agent: row.raw_user_agent,
    created_at: row.created_at,
    updated_at: row.updated_at,
    last_used_at: row.last_used_at,
  ))
}

fn optional_operating_system(
  value: option.Option(String),
) -> option.Option(option.Option(platform_model.OperatingSystem)) {
  case value {
    option.None -> option.Some(option.None)
    option.Some(os_name) ->
      platform_model.operating_system_from_string(os_name)
      |> option.map(option.Some)
  }
}

fn optional_browser(
  value: option.Option(String),
) -> option.Option(option.Option(platform_model.Browser)) {
  case value {
    option.None -> option.Some(option.None)
    option.Some(browser_name) ->
      platform_model.browser_from_string(browser_name)
      |> option.map(option.Some)
  }
}

fn passkey_challenge_from_rows(
  rows: List(sql.GetPasskeyChallengeById),
) -> Result(option.Option(passkey_challenge_model.PasskeyChallenge), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> passkey_challenge_from_row(first) |> result.map(option.Some)
    _ ->
      Error(db_error.DbQueryError(
        "Expected at most one passkey challenge row",
      ))
  }
}

fn passkey_challenge_from_row(
  row: sql.GetPasskeyChallengeById,
) -> Result(passkey_challenge_model.PasskeyChallenge, db_error.DbQueryError) {
  use flow <- result.try(
    passkey_challenge_model.flow_from_string(row.flow)
    |> option.to_result(db_error.DbQueryError(
      "Invalid passkey challenge flow: " <> row.flow,
    )),
  )

  Ok(passkey_challenge_model.PasskeyChallenge(
    id: uuid_helpers.from_bit_array(row.id),
    user_id: option.map(row.user_id, uuid_helpers.from_bit_array),
    flow: flow,
    challenge_state: row.challenge_state,
    created_at: row.created_at,
    expires_at: row.expires_at,
  ))
}

fn session_from_rows(
  is_email: regexp.Regexp,
  rows: List(sql.GetSessionByToken),
) -> Result(option.Option(session_model.HydratedSession), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> session_from_row(is_email, first) |> result.map(option.Some)
    _ -> Error(db_error.DbQueryError("Expected at most one session row"))
  }
}

fn session_identity_from_rows(
  rows: List(sql.GetSessionByTokenForUpdate),
) -> Result(option.Option(session_model.Session), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] -> session_identity_from_row(first) |> result.map(option.Some)
    _ -> Error(db_error.DbQueryError("Expected at most one session row"))
  }
}

fn session_from_previous_rows(
  is_email: regexp.Regexp,
  rows: List(sql.GetSessionByPreviousToken),
) -> Result(option.Option(session_model.HydratedSession), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] ->
      session_from_previous_row(is_email, first)
      |> result.map(option.Some)
    _ -> Error(db_error.DbQueryError("Expected at most one session row"))
  }
}

fn session_identity_from_previous_rows(
  rows: List(sql.GetSessionByPreviousTokenForUpdate),
) -> Result(option.Option(session_model.Session), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [first] ->
      session_identity_from_previous_row(first) |> result.map(option.Some)
    _ -> Error(db_error.DbQueryError("Expected at most one session row"))
  }
}

fn session_from_row(
  is_email: regexp.Regexp,
  row: sql.GetSessionByToken,
) -> Result(session_model.HydratedSession, db_error.DbQueryError) {
  use valid_email <- result.try(
    email_address_model.from_string(is_email, row.user_email)
    |> option.to_result(db_error.DbQueryError(
      "Invalid email format in session row: " <> row.user_email,
    )),
  )
  use role <- result.try(
    user_model.role_from_string(row.user_role)
    |> option.to_result(db_error.DbQueryError(
      "Invalid user role: " <> row.user_role,
    )),
  )
  use account_state <- result.try(
    account_model.account_state_from_string(row.user_account_state)
    |> option.to_result(db_error.DbQueryError(
      "Invalid account state: " <> row.user_account_state,
    )),
  )
  use account_tier <- result.try(
    account_model.account_tier_from_string(row.user_account_tier)
    |> option.to_result(db_error.DbQueryError(
      "Invalid account tier: " <> row.user_account_tier,
    )),
  )
  use os_name <- result.try(
    optional_operating_system(row.os_name)
    |> option.to_result(db_error.DbQueryError("Invalid operating system")),
  )
  use browser_name <- result.try(
    optional_browser(row.browser_name)
    |> option.to_result(db_error.DbQueryError("Invalid browser")),
  )

  Ok(session_model.HydratedSession(
    identity: session_model.Session(
      id: uuid_helpers.from_bit_array(row.id),
      user_id: uuid_helpers.from_bit_array(row.sessions_user_id),
      token: row.token,
      previous_token: row.previous_token,
      previous_token_valid_until: row.previous_token_valid_until,
      ip: row.ip,
      os_name: os_name,
      browser_name: browser_name,
      user_agent: row.user_agent,
      created_at: row.created_at,
      token_updated_at: row.token_updated_at,
    ),
    user: user_model.HydratedUser(
      identity: user_model.User(
        id: uuid_helpers.from_bit_array(row.users_user_id),
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
          delete_job_id: row.user_account_delete_job_id
            |> option.map(uuid_helpers.from_bit_array),
          created_at: row.user_created_at,
          updated_at: row.user_updated_at,
        ),
        delete_scheduled_at: row.user_account_delete_scheduled_at,
      ),
    ),
  ))
}

fn session_identity_from_row(
  row: sql.GetSessionByTokenForUpdate,
) -> Result(session_model.Session, db_error.DbQueryError) {
  use os_name <- result.try(
    optional_operating_system(row.os_name)
    |> option.to_result(db_error.DbQueryError("Invalid operating system")),
  )
  use browser_name <- result.try(
    optional_browser(row.browser_name)
    |> option.to_result(db_error.DbQueryError("Invalid browser")),
  )

  Ok(session_model.Session(
    id: uuid_helpers.from_bit_array(row.id),
    user_id: uuid_helpers.from_bit_array(row.user_id),
    token: row.token,
    previous_token: row.previous_token,
    previous_token_valid_until: row.previous_token_valid_until,
    ip: row.ip,
    os_name: os_name,
    browser_name: browser_name,
    user_agent: row.user_agent,
    created_at: row.created_at,
    token_updated_at: row.token_updated_at,
  ))
}

fn session_from_previous_row(
  is_email: regexp.Regexp,
  row: sql.GetSessionByPreviousToken,
) -> Result(session_model.HydratedSession, db_error.DbQueryError) {
  use valid_email <- result.try(
    email_address_model.from_string(is_email, row.user_email)
    |> option.to_result(db_error.DbQueryError(
      "Invalid email format in session row: " <> row.user_email,
    )),
  )
  use role <- result.try(
    user_model.role_from_string(row.user_role)
    |> option.to_result(db_error.DbQueryError(
      "Invalid user role: " <> row.user_role,
    )),
  )
  use account_state <- result.try(
    account_model.account_state_from_string(row.user_account_state)
    |> option.to_result(db_error.DbQueryError(
      "Invalid account state: " <> row.user_account_state,
    )),
  )
  use account_tier <- result.try(
    account_model.account_tier_from_string(row.user_account_tier)
    |> option.to_result(db_error.DbQueryError(
      "Invalid account tier: " <> row.user_account_tier,
    )),
  )
  use os_name <- result.try(
    optional_operating_system(row.os_name)
    |> option.to_result(db_error.DbQueryError("Invalid operating system")),
  )
  use browser_name <- result.try(
    optional_browser(row.browser_name)
    |> option.to_result(db_error.DbQueryError("Invalid browser")),
  )

  Ok(session_model.HydratedSession(
    identity: session_model.Session(
      id: uuid_helpers.from_bit_array(row.id),
      user_id: uuid_helpers.from_bit_array(row.sessions_user_id),
      token: row.token,
      previous_token: row.previous_token,
      previous_token_valid_until: row.previous_token_valid_until,
      ip: row.ip,
      os_name: os_name,
      browser_name: browser_name,
      user_agent: row.user_agent,
      created_at: row.created_at,
      token_updated_at: row.token_updated_at,
    ),
    user: user_model.HydratedUser(
      identity: user_model.User(
        id: uuid_helpers.from_bit_array(row.users_user_id),
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
          delete_job_id: row.user_account_delete_job_id
            |> option.map(uuid_helpers.from_bit_array),
          created_at: row.user_created_at,
          updated_at: row.user_updated_at,
        ),
        delete_scheduled_at: row.user_account_delete_scheduled_at,
      ),
    ),
  ))
}

fn session_identity_from_previous_row(
  row: sql.GetSessionByPreviousTokenForUpdate,
) -> Result(session_model.Session, db_error.DbQueryError) {
  use os_name <- result.try(
    optional_operating_system(row.os_name)
    |> option.to_result(db_error.DbQueryError("Invalid operating system")),
  )
  use browser_name <- result.try(
    optional_browser(row.browser_name)
    |> option.to_result(db_error.DbQueryError("Invalid browser")),
  )

  Ok(session_model.Session(
    id: uuid_helpers.from_bit_array(row.id),
    user_id: uuid_helpers.from_bit_array(row.user_id),
    token: row.token,
    previous_token: row.previous_token,
    previous_token_valid_until: row.previous_token_valid_until,
    ip: row.ip,
    os_name: os_name,
    browser_name: browser_name,
    user_agent: row.user_agent,
    created_at: row.created_at,
    token_updated_at: row.token_updated_at,
  ))
}
