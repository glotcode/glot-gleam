import gleam/json
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/db_helpers
import glot_backend/effect/error
import glot_backend/effect/snippet/snippet
import glot_backend/sql
import glot_core/language
import glot_core/snippet as snippet_type
import pog
import youid/uuid

pub fn run_command(
  db: pog.Connection,
  command: snippet.SnippetCommand,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  case command {
    snippet.InsertSnippet(
      id: id,
      user_id: user_id,
      snippet: s,
      created_at: created_at,
      updated_at: updated_at,
    ) ->
      insert_snippet(
        db: db,
        id: id,
        user_id: user_id,
        snippet: s,
        created_at: created_at,
        updated_at: updated_at,
        to_error: to_error,
      )
  }
}

fn insert_snippet(
  db db: pog.Connection,
  id id: uuid.Uuid,
  user_id user_id: uuid.Uuid,
  snippet snippet: snippet_type.Snippet,
  created_at created_at: Timestamp,
  updated_at updated_at: Timestamp,
  to_error to_error: fn(pog.QueryError) -> error.DbCommandError,
) -> Result(Nil, error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.insert_snippet(
      id: uuid.to_bit_array(id),
      user_id: uuid.to_bit_array(user_id),
      language: language.to_string(snippet.language),
      title: snippet.title,
      visibility: snippet_type.visibility_to_string(snippet.visibility),
      stdin: snippet.stdin,
      run_command: snippet.run_command,
      files: json.to_string(json.array(snippet.files, snippet_type.encode_file)),
      created_at: created_at,
      updated_at: updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}
