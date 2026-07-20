import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import glot_backend/sql
import glot_backend/system/effect/error/db_error
import glot_core/auth/account_model
import glot_core/auth/platform_model
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/uuid_helpers

pub fn hydrated_from_token_rows(
  is_email: regexp.Regexp,
  rows: List(sql.GetSessionByToken),
) -> Result(option.Option(session_model.HydratedSession), db_error.DbQueryError) {
  decode_optional(rows, fn(row) { hydrated_from_token_row(is_email, row) })
}

pub fn identity_from_token_for_update_rows(
  rows: List(sql.GetSessionByTokenForUpdate),
) -> Result(option.Option(session_model.Session), db_error.DbQueryError) {
  decode_optional(rows, identity_from_token_for_update_row)
}

pub fn hydrated_from_previous_token_rows(
  is_email: regexp.Regexp,
  rows: List(sql.GetSessionByPreviousToken),
) -> Result(option.Option(session_model.HydratedSession), db_error.DbQueryError) {
  decode_optional(rows, fn(row) {
    hydrated_from_previous_token_row(is_email, row)
  })
}

pub fn identity_from_previous_token_for_update_rows(
  rows: List(sql.GetSessionByPreviousTokenForUpdate),
) -> Result(option.Option(session_model.Session), db_error.DbQueryError) {
  decode_optional(rows, identity_from_previous_token_for_update_row)
}

pub fn identities_from_list_rows(
  rows: List(sql.ListSessionsByUserId),
) -> Result(List(session_model.Session), db_error.DbQueryError) {
  rows
  |> list.map(identity_from_list_row)
  |> result.all
}

fn decode_optional(
  rows: List(row),
  decoder: fn(row) -> Result(value, db_error.DbQueryError),
) -> Result(option.Option(value), db_error.DbQueryError) {
  case rows {
    [] -> Ok(option.None)
    [row] -> decoder(row) |> result.map(option.Some)
    _ -> Error(db_error.DbQueryError("Expected at most one session row"))
  }
}

fn hydrated_from_token_row(
  is_email: regexp.Regexp,
  row: sql.GetSessionByToken,
) -> Result(session_model.HydratedSession, db_error.DbQueryError) {
  hydrated_from_fields(
    is_email: is_email,
    id: row.id,
    session_user_id: row.sessions_user_id,
    token: row.token,
    previous_token: row.previous_token,
    previous_token_valid_until: row.previous_token_valid_until,
    ip: row.ip,
    os_name: row.os_name,
    browser_name: row.browser_name,
    user_agent: row.user_agent,
    session_created_at: row.created_at,
    token_updated_at: row.token_updated_at,
    last_activity_at: row.last_activity_at,
    user_id: row.users_user_id,
    account_id: row.user_account_id,
    email: row.user_email,
    username: row.user_username,
    role_name: row.user_role,
    last_login_at: row.user_last_login_at,
    user_created_at: row.user_created_at,
    user_updated_at: row.user_updated_at,
    account_state_name: row.user_account_state,
    account_state_reason: row.user_account_state_reason,
    account_tier_name: row.user_account_tier,
    account_delete_job_id: row.user_account_delete_job_id,
    account_delete_scheduled_at: row.user_account_delete_scheduled_at,
  )
}

fn hydrated_from_previous_token_row(
  is_email: regexp.Regexp,
  row: sql.GetSessionByPreviousToken,
) -> Result(session_model.HydratedSession, db_error.DbQueryError) {
  hydrated_from_fields(
    is_email: is_email,
    id: row.id,
    session_user_id: row.sessions_user_id,
    token: row.token,
    previous_token: row.previous_token,
    previous_token_valid_until: row.previous_token_valid_until,
    ip: row.ip,
    os_name: row.os_name,
    browser_name: row.browser_name,
    user_agent: row.user_agent,
    session_created_at: row.created_at,
    token_updated_at: row.token_updated_at,
    last_activity_at: row.last_activity_at,
    user_id: row.users_user_id,
    account_id: row.user_account_id,
    email: row.user_email,
    username: row.user_username,
    role_name: row.user_role,
    last_login_at: row.user_last_login_at,
    user_created_at: row.user_created_at,
    user_updated_at: row.user_updated_at,
    account_state_name: row.user_account_state,
    account_state_reason: row.user_account_state_reason,
    account_tier_name: row.user_account_tier,
    account_delete_job_id: row.user_account_delete_job_id,
    account_delete_scheduled_at: row.user_account_delete_scheduled_at,
  )
}

fn hydrated_from_fields(
  is_email is_email: regexp.Regexp,
  id id,
  session_user_id session_user_id,
  token token,
  previous_token previous_token,
  previous_token_valid_until previous_token_valid_until,
  ip ip,
  os_name os_name,
  browser_name browser_name,
  user_agent user_agent,
  session_created_at session_created_at,
  token_updated_at token_updated_at,
  last_activity_at last_activity_at,
  user_id user_id,
  account_id account_id,
  email email: String,
  username username,
  role_name role_name: String,
  last_login_at last_login_at,
  user_created_at user_created_at,
  user_updated_at user_updated_at,
  account_state_name account_state_name: String,
  account_state_reason account_state_reason,
  account_tier_name account_tier_name: String,
  account_delete_job_id account_delete_job_id,
  account_delete_scheduled_at account_delete_scheduled_at,
) -> Result(session_model.HydratedSession, db_error.DbQueryError) {
  use valid_email <- result.try(
    email_address_model.from_string(is_email, email)
    |> option.to_result(db_error.DbQueryError(
      "Invalid email format in session row: " <> email,
    )),
  )
  use role <- result.try(
    user_model.role_from_string(role_name)
    |> option.to_result(db_error.DbQueryError(
      "Invalid user role: " <> role_name,
    )),
  )
  use account_state <- result.try(
    account_model.account_state_from_string(account_state_name)
    |> option.to_result(db_error.DbQueryError(
      "Invalid account state: " <> account_state_name,
    )),
  )
  use account_tier <- result.try(
    account_model.account_tier_from_string(account_tier_name)
    |> option.to_result(db_error.DbQueryError(
      "Invalid account tier: " <> account_tier_name,
    )),
  )
  use operating_system <- result.try(decode_operating_system(os_name))
  use browser <- result.try(decode_browser(browser_name))

  Ok(session_model.HydratedSession(
    identity: session_model.Session(
      id: uuid_helpers.from_bit_array(id),
      user_id: uuid_helpers.from_bit_array(session_user_id),
      token: token,
      previous_token: previous_token,
      previous_token_valid_until: previous_token_valid_until,
      ip: ip,
      os_name: operating_system,
      browser_name: browser,
      user_agent: user_agent,
      created_at: session_created_at,
      token_updated_at: token_updated_at,
      last_activity_at: last_activity_at,
    ),
    user: user_model.HydratedUser(
      identity: user_model.User(
        id: uuid_helpers.from_bit_array(user_id),
        account_id: uuid_helpers.from_bit_array(account_id),
        email: valid_email,
        username: username,
        role: role,
        last_login_at: last_login_at,
        created_at: user_created_at,
        updated_at: user_updated_at,
      ),
      account: account_model.HydratedAccount(
        identity: account_model.Account(
          id: uuid_helpers.from_bit_array(account_id),
          account_state: account_state,
          account_state_reason: account_state_reason,
          account_tier: account_tier,
          delete_job_id: account_delete_job_id
            |> option.map(uuid_helpers.from_bit_array),
          created_at: user_created_at,
          updated_at: user_updated_at,
        ),
        delete_scheduled_at: account_delete_scheduled_at,
      ),
    ),
  ))
}

fn identity_from_token_for_update_row(
  row: sql.GetSessionByTokenForUpdate,
) -> Result(session_model.Session, db_error.DbQueryError) {
  identity_from_fields(
    id: row.id,
    user_id: row.user_id,
    token: row.token,
    previous_token: row.previous_token,
    previous_token_valid_until: row.previous_token_valid_until,
    ip: row.ip,
    os_name: row.os_name,
    browser_name: row.browser_name,
    user_agent: row.user_agent,
    created_at: row.created_at,
    token_updated_at: row.token_updated_at,
    last_activity_at: row.last_activity_at,
  )
}

fn identity_from_previous_token_for_update_row(
  row: sql.GetSessionByPreviousTokenForUpdate,
) -> Result(session_model.Session, db_error.DbQueryError) {
  identity_from_fields(
    id: row.id,
    user_id: row.user_id,
    token: row.token,
    previous_token: row.previous_token,
    previous_token_valid_until: row.previous_token_valid_until,
    ip: row.ip,
    os_name: row.os_name,
    browser_name: row.browser_name,
    user_agent: row.user_agent,
    created_at: row.created_at,
    token_updated_at: row.token_updated_at,
    last_activity_at: row.last_activity_at,
  )
}

fn identity_from_list_row(
  row: sql.ListSessionsByUserId,
) -> Result(session_model.Session, db_error.DbQueryError) {
  identity_from_fields(
    id: row.id,
    user_id: row.user_id,
    token: row.token,
    previous_token: row.previous_token,
    previous_token_valid_until: row.previous_token_valid_until,
    ip: row.ip,
    os_name: row.os_name,
    browser_name: row.browser_name,
    user_agent: row.user_agent,
    created_at: row.created_at,
    token_updated_at: row.token_updated_at,
    last_activity_at: row.last_activity_at,
  )
}

fn identity_from_fields(
  id id,
  user_id user_id,
  token token,
  previous_token previous_token,
  previous_token_valid_until previous_token_valid_until,
  ip ip,
  os_name os_name,
  browser_name browser_name,
  user_agent user_agent,
  created_at created_at,
  token_updated_at token_updated_at,
  last_activity_at last_activity_at,
) -> Result(session_model.Session, db_error.DbQueryError) {
  use operating_system <- result.try(decode_operating_system(os_name))
  use browser <- result.try(decode_browser(browser_name))

  Ok(session_model.Session(
    id: uuid_helpers.from_bit_array(id),
    user_id: uuid_helpers.from_bit_array(user_id),
    token: token,
    previous_token: previous_token,
    previous_token_valid_until: previous_token_valid_until,
    ip: ip,
    os_name: operating_system,
    browser_name: browser,
    user_agent: user_agent,
    created_at: created_at,
    token_updated_at: token_updated_at,
    last_activity_at: last_activity_at,
  ))
}

fn decode_operating_system(
  value: option.Option(String),
) -> Result(
  option.Option(platform_model.OperatingSystem),
  db_error.DbQueryError,
) {
  optional_operating_system(value)
  |> option.to_result(db_error.DbQueryError("Invalid operating system"))
}

fn decode_browser(
  value: option.Option(String),
) -> Result(option.Option(platform_model.Browser), db_error.DbQueryError) {
  optional_browser(value)
  |> option.to_result(db_error.DbQueryError("Invalid browser"))
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
