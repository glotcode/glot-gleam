import gleam/json
import gleam/result
import gleam/string
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/sql
import glot_core/language
import glot_core/snippet.{type Snippet} as snippet_type
import pog
import youid/uuid

pub type SnippetHandlers {
  SnippetHandlers(
    create_snippet: fn(Snippet) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> SnippetHandlers {
  SnippetHandlers(create_snippet: fn(snippet) { create_snippet(db, snippet) })
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
      language: language.to_string(snippet.data.language),
      title: snippet.data.title,
      visibility: snippet_type.visibility_to_string(snippet.data.visibility),
      stdin: snippet.data.stdin,
      run_command: snippet.data.run_command,
      files: json.to_string(json.array(
        snippet.data.files,
        snippet_type.encode_file,
      )),
      created_at: snippet.created_at,
      updated_at: snippet.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}
