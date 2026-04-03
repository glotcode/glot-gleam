import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/result
import gleam/string
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/sql
import glot_core/email/email_address_model
import glot_core/language
import glot_core/snippet/snippet_model.{type HydratedSnippet, type Snippet}
import glot_core/user
import glot_core/uuid_helpers
import pog
import youid/uuid

pub type SnippetHandlers {
  SnippetHandlers(
    get_snippet_by_id: fn(BitArray) ->
      Result(option.Option(HydratedSnippet), error.DbQueryError),
    delete_snippet: fn(BitArray) -> Result(Nil, error.DbCommandError),
    create_snippet: fn(Snippet) -> Result(Nil, error.DbCommandError),
    update_snippet: fn(Snippet) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> SnippetHandlers {
  SnippetHandlers(
    get_snippet_by_id: fn(id) { get_snippet_by_id(db, id) },
    delete_snippet: fn(id) { delete_snippet(db, id) },
    create_snippet: fn(snippet) { create_snippet(db, snippet) },
    update_snippet: fn(snippet) { update_snippet(db, snippet) },
  )
}

pub fn get_snippet_by_id(
  db: pog.Connection,
  id: BitArray,
) -> Result(option.Option(HydratedSnippet), error.DbQueryError) {
  use returned <- result.try(
    db_helpers.query(db, sql.get_snippet_by_id(id), fn(err) {
      error.DbQueryError(string.inspect(err))
    }),
  )

  case returned.rows {
    [] -> Ok(option.None)
    [row] -> get_snippet_from_row(row) |> result.map(option.Some)
    _ -> Error(error.DbQueryError("Expected at most one snippet row"))
  }
}

pub fn create_snippet(
  db: pog.Connection,
  snippet: Snippet,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_snippet(
      id: uuid.to_bit_array(snippet.id),
      user_id: uuid.to_bit_array(snippet.user_id),
      language: language.to_string(snippet.language),
      title: snippet.title,
      visibility: snippet_model.visibility_to_string(snippet.visibility),
      stdin: snippet.stdin,
      run_command: snippet.run_command,
      files: json.to_string(json.array(snippet.files, snippet_model.encode_file)),
      created_at: snippet.created_at,
      updated_at: snippet.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

pub fn delete_snippet(
  db: pog.Connection,
  id: BitArray,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_snippet(id), to_error)
  |> result.map(fn(_) { Nil })
}

fn get_snippet_from_row(
  row: sql.GetSnippetById,
) -> Result(HydratedSnippet, error.DbQueryError) {
  use language <- result.try(
    language.from_string(row.language)
    |> option.to_result(error.DbQueryError(
      "Invalid snippet language: " <> row.language,
    )),
  )
  use visibility <- result.try(
    snippet_model.visibility_from_string(row.visibility)
    |> option.to_result(error.DbQueryError(
      "Invalid snippet visibility: " <> row.visibility,
    )),
  )
  use files <- result.try(
    json.parse(row.files, decode.list(snippet_model.file_decoder()))
    |> result.map_error(fn(decode_errors) {
      error.DbQueryError(
        "Invalid snippet files: " <> string.inspect(decode_errors),
      )
    }),
  )

  Ok(snippet_model.HydratedSnippet(
    id: uuid_helpers.from_bit_array(row.id),
    user: user.User(
      id: uuid_helpers.from_bit_array(row.user_id),
      email: email_address_model.EmailAddress(row.user_email),
      created_at: row.user_created_at,
    ),
    title: row.title,
    language: language,
    visibility: visibility,
    stdin: row.stdin,
    run_command: row.run_command,
    files: files,
    created_at: row.created_at,
    updated_at: row.updated_at,
  ))
}

pub fn update_snippet(
  db: pog.Connection,
  snippet: Snippet,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_snippet(
      id: uuid.to_bit_array(snippet.id),
      user_id: uuid.to_bit_array(snippet.user_id),
      language: language.to_string(snippet.language),
      title: snippet.title,
      visibility: snippet_model.visibility_to_string(snippet.visibility),
      stdin: snippet.stdin,
      run_command: snippet.run_command,
      files: json.to_string(json.array(snippet.files, snippet_model.encode_file)),
      created_at: snippet.created_at,
      updated_at: snippet.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}
