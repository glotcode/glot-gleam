import gleam/json
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/sql
import glot_core/language
import glot_core/snippet as snippet_type
import pog
import youid/uuid

pub type SnippetHandlers {
  SnippetHandlers(
    insert_snippet: fn(
      uuid.Uuid,
      uuid.Uuid,
      snippet_type.Snippet,
      Timestamp,
      Timestamp,
    ) -> Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> SnippetHandlers {
  SnippetHandlers(
    insert_snippet: fn(id, user_id, snippet, created_at, updated_at) {
      insert_snippet(db, id, user_id, snippet, created_at, updated_at)
    },
  )
}

pub fn insert_snippet(
  db: pog.Connection,
  id: uuid.Uuid,
  user_id: uuid.Uuid,
  snippet_value: snippet_type.Snippet,
  created_at: Timestamp,
  updated_at: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.insert_snippet(
      id: uuid.to_bit_array(id),
      user_id: uuid.to_bit_array(user_id),
      language: language.to_string(snippet_value.language),
      title: snippet_value.title,
      visibility: snippet_type.visibility_to_string(snippet_value.visibility),
      stdin: snippet_value.stdin,
      run_command: snippet_value.run_command,
      files: json.to_string(json.array(snippet_value.files, snippet_type.encode_file)),
      created_at: created_at,
      updated_at: updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}
