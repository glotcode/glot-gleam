//// This module contains the code to run the sql queries defined in
//// `./src/glot_backend/sql`.
//// > 🐿️ This module was generated automatically using v4.6.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/json.{type Json}
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog
import youid/uuid.{type Uuid}

/// A row you get from running the `count_user_activities_by_ip_and_operation` query
/// defined in `./src/glot_backend/sql/count_user_activities_by_ip_and_operation.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CountUserActivitiesByIpAndOperationRow {
  CountUserActivitiesByIpAndOperationRow(count: Int)
}

/// Runs the `count_user_activities_by_ip_and_operation` query
/// defined in `./src/glot_backend/sql/count_user_activities_by_ip_and_operation.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn count_user_activities_by_ip_and_operation(
  db: pog.Connection,
  arg_1: Timestamp,
  arg_2: String,
  arg_3: UserAction,
) -> Result(
  pog.Returned(CountUserActivitiesByIpAndOperationRow),
  pog.QueryError,
) {
  let decoder = {
    use count <- decode.field(0, decode.int)
    decode.success(CountUserActivitiesByIpAndOperationRow(count:))
  }

  "SELECT COUNT(*) as count FROM user_activities WHERE created_at >= $1 and ip = $2 AND action = $3;"
  |> pog.query
  |> pog.parameter(pog.timestamp(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(user_action_encoder(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `delete_snippet` query
/// defined in `./src/glot_backend/sql/delete_snippet.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_snippet(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "DELETE FROM snippets WHERE id = $1;"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_session_by_token_hash` query
/// defined in `./src/glot_backend/sql/get_session_by_token_hash.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetSessionByTokenHashRow {
  GetSessionByTokenHashRow(
    id: Uuid,
    user_id: Uuid,
    token_hash: String,
    ip: String,
    user_agent: String,
    country: String,
    created_at: Timestamp,
  )
}

/// Runs the `get_session_by_token_hash` query
/// defined in `./src/glot_backend/sql/get_session_by_token_hash.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_session_by_token_hash(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(GetSessionByTokenHashRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use user_id <- decode.field(1, uuid_decoder())
    use token_hash <- decode.field(2, decode.string)
    use ip <- decode.field(3, decode.string)
    use user_agent <- decode.field(4, decode.string)
    use country <- decode.field(5, decode.string)
    use created_at <- decode.field(6, pog.timestamp_decoder())
    decode.success(GetSessionByTokenHashRow(
      id:,
      user_id:,
      token_hash:,
      ip:,
      user_agent:,
      country:,
      created_at:,
    ))
  }

  "SELECT id, user_id, token_hash, ip, user_agent, country, created_at FROM sessions WHERE token_hash = $1"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_snippet_by_id` query
/// defined in `./src/glot_backend/sql/get_snippet_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetSnippetByIdRow {
  GetSnippetByIdRow(
    id: Uuid,
    user_id: Uuid,
    language: String,
    title: String,
    visibility: String,
    stdin: String,
    run_command: String,
    files: String,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// Runs the `get_snippet_by_id` query
/// defined in `./src/glot_backend/sql/get_snippet_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_snippet_by_id(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(GetSnippetByIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use user_id <- decode.field(1, uuid_decoder())
    use language <- decode.field(2, decode.string)
    use title <- decode.field(3, decode.string)
    use visibility <- decode.field(4, decode.string)
    use stdin <- decode.field(5, decode.string)
    use run_command <- decode.field(6, decode.string)
    use files <- decode.field(7, decode.string)
    use created_at <- decode.field(8, pog.timestamp_decoder())
    use updated_at <- decode.field(9, pog.timestamp_decoder())
    decode.success(GetSnippetByIdRow(
      id:,
      user_id:,
      language:,
      title:,
      visibility:,
      stdin:,
      run_command:,
      files:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT id, user_id, language, title, visibility, stdin, run_command, files, created_at, updated_at FROM snippets WHERE id = $1"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_user_by_email` query
/// defined in `./src/glot_backend/sql/get_user_by_email.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetUserByEmailRow {
  GetUserByEmailRow(id: Uuid, email: String, created_at: Timestamp)
}

/// Runs the `get_user_by_email` query
/// defined in `./src/glot_backend/sql/get_user_by_email.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_user_by_email(
  db: pog.Connection,
  arg_1: String,
) -> Result(pog.Returned(GetUserByEmailRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    use created_at <- decode.field(2, pog.timestamp_decoder())
    decode.success(GetUserByEmailRow(id:, email:, created_at:))
  }

  "SELECT id, email, created_at FROM users WHERE email = $1"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_user_by_id` query
/// defined in `./src/glot_backend/sql/get_user_by_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetUserByIdRow {
  GetUserByIdRow(id: Uuid, email: String, created_at: Timestamp)
}

/// Runs the `get_user_by_id` query
/// defined in `./src/glot_backend/sql/get_user_by_id.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_user_by_id(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(GetUserByIdRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use email <- decode.field(1, decode.string)
    use created_at <- decode.field(2, pog.timestamp_decoder())
    decode.success(GetUserByIdRow(id:, email:, created_at:))
  }

  "SELECT id, email, created_at FROM users WHERE id = $1"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_login_token` query
/// defined in `./src/glot_backend/sql/insert_login_token.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_login_token(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
  arg_3: String,
  arg_4: Timestamp,
  arg_5: Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO login_tokens (id, user_id, token_hash, created_at, used_at) VALUES ($1, $2, $3, $4, $5)"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.timestamp(arg_4))
  |> pog.parameter(pog.timestamp(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_session` query
/// defined in `./src/glot_backend/sql/insert_session.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_session(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO sessions (id, user_id, token_hash, ip, user_agent, country, created_at) VALUES ($1, $2, $3, $4, $5, $6, $7)"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.timestamp(arg_7))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_snippet` query
/// defined in `./src/glot_backend/sql/insert_snippet.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_snippet(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: Uuid,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: String,
  arg_8: Json,
  arg_9: Timestamp,
  arg_10: Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO snippets (id, user_id, language, title, visibility, stdin, run_command, files, created_at, updated_at) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(uuid.to_string(arg_2)))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.text(arg_7))
  |> pog.parameter(pog.text(json.to_string(arg_8)))
  |> pog.parameter(pog.timestamp(arg_9))
  |> pog.parameter(pog.timestamp(arg_10))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_user` query
/// defined in `./src/glot_backend/sql/insert_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_user(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO users (id, email, created_at) VALUES ($1, $2, $3)"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_user_activity` query
/// defined in `./src/glot_backend/sql/insert_user_activity.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_user_activity(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: UserAction,
  arg_3: String,
  arg_4: String,
  arg_5: Timestamp,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "INSERT INTO user_activities (id, action, ip, session_token_hash, created_at) VALUES ($1, $2, $3, $4, $5)"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(user_action_encoder(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.timestamp(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_snippets_by_user` query
/// defined in `./src/glot_backend/sql/list_snippets_by_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListSnippetsByUserRow {
  ListSnippetsByUserRow(
    id: Uuid,
    user_id: Uuid,
    language: String,
    title: String,
    visibility: String,
    stdin: String,
    run_command: String,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

/// Runs the `list_snippets_by_user` query
/// defined in `./src/glot_backend/sql/list_snippets_by_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_snippets_by_user(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(ListSnippetsByUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use user_id <- decode.field(1, uuid_decoder())
    use language <- decode.field(2, decode.string)
    use title <- decode.field(3, decode.string)
    use visibility <- decode.field(4, decode.string)
    use stdin <- decode.field(5, decode.string)
    use run_command <- decode.field(6, decode.string)
    use created_at <- decode.field(7, pog.timestamp_decoder())
    use updated_at <- decode.field(8, pog.timestamp_decoder())
    decode.success(ListSnippetsByUserRow(
      id:,
      user_id:,
      language:,
      title:,
      visibility:,
      stdin:,
      run_command:,
      created_at:,
      updated_at:,
    ))
  }

  "SELECT id, user_id, language, title, visibility, stdin, run_command, created_at, updated_at FROM snippets WHERE user_id = $1"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_unused_login_tokens_by_user` query
/// defined in `./src/glot_backend/sql/list_unused_login_tokens_by_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListUnusedLoginTokensByUserRow {
  ListUnusedLoginTokensByUserRow(
    id: Uuid,
    user_id: Uuid,
    token_hash: String,
    created_at: Timestamp,
    used_at: Option(Timestamp),
  )
}

/// Runs the `list_unused_login_tokens_by_user` query
/// defined in `./src/glot_backend/sql/list_unused_login_tokens_by_user.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_unused_login_tokens_by_user(
  db: pog.Connection,
  arg_1: Uuid,
) -> Result(pog.Returned(ListUnusedLoginTokensByUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, uuid_decoder())
    use user_id <- decode.field(1, uuid_decoder())
    use token_hash <- decode.field(2, decode.string)
    use created_at <- decode.field(3, pog.timestamp_decoder())
    use used_at <- decode.field(4, decode.optional(pog.timestamp_decoder()))
    decode.success(ListUnusedLoginTokensByUserRow(
      id:,
      user_id:,
      token_hash:,
      created_at:,
      used_at:,
    ))
  }

  "SELECT id, user_id, token_hash, created_at, used_at FROM login_tokens WHERE user_id = $1 AND used_at IS NULL ORDER BY created_at DESC"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `update_login_token` query
/// defined in `./src/glot_backend/sql/update_login_token.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_login_token(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: Timestamp,
  arg_4: Timestamp,
  arg_5: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE login_tokens SET user_id = $1, token_hash = $2, created_at = $3, used_at = $4 WHERE id = $5"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.timestamp(arg_3))
  |> pog.parameter(pog.timestamp(arg_4))
  |> pog.parameter(pog.text(uuid.to_string(arg_5)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `update_snippet` query
/// defined in `./src/glot_backend/sql/update_snippet.sql`.
///
/// > 🐿️ This function was generated automatically using v4.6.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_snippet(
  db: pog.Connection,
  arg_1: Uuid,
  arg_2: String,
  arg_3: String,
  arg_4: String,
  arg_5: String,
  arg_6: String,
  arg_7: Timestamp,
  arg_8: Timestamp,
  arg_9: Uuid,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "UPDATE snippets SET user_id = $1, language = $2, title = $3, visibility = $4, stdin = $5, run_command = $6, created_at = $7, updated_at = $8 WHERE id = $9"
  |> pog.query
  |> pog.parameter(pog.text(uuid.to_string(arg_1)))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.text(arg_4))
  |> pog.parameter(pog.text(arg_5))
  |> pog.parameter(pog.text(arg_6))
  |> pog.parameter(pog.timestamp(arg_7))
  |> pog.parameter(pog.timestamp(arg_8))
  |> pog.parameter(pog.text(uuid.to_string(arg_9)))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Enums -------------------------------------------------------------------

/// Corresponds to the Postgres `user_action` enum.
///
/// > 🐿️ This type definition was generated automatically using v4.6.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UserAction {
  DeleteSnippetAction
  UpdateSnippetAction
  CreateSnippetAction
  RunSnippetAction
  LoginAction
  SendLoginTokenAction
}

fn user_action_encoder(user_action) -> pog.Value {
  case user_action {
    DeleteSnippetAction -> "delete_snippet_action"
    UpdateSnippetAction -> "update_snippet_action"
    CreateSnippetAction -> "create_snippet_action"
    RunSnippetAction -> "run_snippet_action"
    LoginAction -> "login_action"
    SendLoginTokenAction -> "send_login_token_action"
  }
  |> pog.text
}

// --- Encoding/decoding utils -------------------------------------------------

/// A decoder to decode `Uuid`s coming from a Postgres query.
///
fn uuid_decoder() {
  use bit_array <- decode.then(decode.bit_array)
  case uuid.from_bit_array(bit_array) {
    Ok(uuid) -> decode.success(uuid)
    Error(_) -> decode.failure(uuid.v7(), "Uuid")
  }
}
