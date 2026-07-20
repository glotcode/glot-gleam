import gleam/option
import gleam/result
import gleam/string
import glot_backend/auth/ports/passkey_store
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import glot_core/auth/platform_model
import glot_core/helpers/uuid_helpers
import youid/uuid

pub fn new(db: db_helpers.Db) -> passkey_store.PasskeyStore {
  passkey_store.PasskeyStore(
    get_credential_by_credential_id: fn(id) {
      get_credential_by_credential_id(db, id)
    },
    list_credentials_by_user_id: fn(id) { list_credentials_by_user_id(db, id) },
    get_challenge_by_id: fn(id) { get_challenge_by_id(db, id) },
    create_credential: fn(credential) { create_credential(db, credential) },
    update_credential: fn(credential) { update_credential(db, credential) },
    delete_credential: fn(id) { delete_credential(db, id) },
    create_challenge: fn(challenge) { create_challenge(db, challenge) },
    delete_challenge: fn(id) { delete_challenge(db, id) },
  )
}

fn get_credential_by_credential_id(
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

fn list_credentials_by_user_id(
  db: db_helpers.Db,
  user_id: uuid.Uuid,
) -> Result(
  List(passkey_credential_model.PasskeyCredential),
  db_error.DbQueryError,
) {
  db_helpers.query(
    db,
    sql.list_passkey_credentials_by_user_id(uuid.to_bit_array(user_id)),
    fn(err) { db_error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { passkey_credentials_from_rows(returned.rows) })
}

fn get_challenge_by_id(
  db: db_helpers.Db,
  id: uuid.Uuid,
) -> Result(
  option.Option(passkey_challenge_model.PasskeyChallenge),
  db_error.DbQueryError,
) {
  db_helpers.query(
    db,
    sql.get_passkey_challenge_by_id(uuid.to_bit_array(id)),
    fn(err) { db_error.DbQueryError(string.inspect(err)) },
  )
  |> result.try(fn(returned) { passkey_challenge_from_rows(returned.rows) })
}

fn create_credential(
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
      user_agent: passkey_credential.user_agent,
      created_at: passkey_credential.created_at,
      updated_at: passkey_credential.updated_at,
      last_used_at: passkey_credential.last_used_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn update_credential(
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
      user_agent: passkey_credential.user_agent,
      created_at: passkey_credential.created_at,
      updated_at: passkey_credential.updated_at,
      last_used_at: passkey_credential.last_used_at,
      id: uuid.to_bit_array(passkey_credential.id),
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn delete_credential(
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

fn create_challenge(
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

fn delete_challenge(
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

fn passkey_credential_from_lookup_rows(
  rows: List(sql.GetPasskeyCredentialByCredentialId),
) -> Result(
  option.Option(passkey_credential_model.PasskeyCredential),
  db_error.DbQueryError,
) {
  case rows {
    [] -> Ok(option.None)
    [first] ->
      passkey_credential_from_lookup_row(first) |> result.map(option.Some)
    _ ->
      Error(db_error.DbQueryError("Expected at most one passkey credential row"))
  }
}

fn passkey_credentials_from_rows(
  rows: List(sql.ListPasskeyCredentialsByUserId),
) -> Result(
  List(passkey_credential_model.PasskeyCredential),
  db_error.DbQueryError,
) {
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
    user_agent: row.user_agent,
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
    user_agent: row.user_agent,
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
) -> Result(
  option.Option(passkey_challenge_model.PasskeyChallenge),
  db_error.DbQueryError,
) {
  case rows {
    [] -> Ok(option.None)
    [first] -> passkey_challenge_from_row(first) |> result.map(option.Some)
    _ ->
      Error(db_error.DbQueryError("Expected at most one passkey challenge row"))
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
