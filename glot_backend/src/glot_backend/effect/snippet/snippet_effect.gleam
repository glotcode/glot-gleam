import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/program_types
import glot_backend/effect/error
import glot_backend/effect/snippet/snippet
import glot_core/snippet as snippet_type
import youid/uuid.{type Uuid}

pub fn insert(
  id id: Uuid,
  user_id user_id: Uuid,
  snippet snippet: snippet_type.Snippet,
  created_at created_at: Timestamp,
  updated_at updated_at: Timestamp,
) -> program_types.Program(Nil) {
  program_types.Impure(program_types.SnippetEffect(snippet.InsertSnippet(
    id: id,
    user_id: user_id,
    snippet: snippet,
    created_at: created_at,
    updated_at: updated_at,
    next: command_next,
  )))
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}
