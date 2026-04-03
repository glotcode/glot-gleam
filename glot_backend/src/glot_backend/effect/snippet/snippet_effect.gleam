import gleam/option
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet
import glot_core/snippet.{type Snippet} as _
import youid/uuid

pub fn get_by_id(id: uuid.Uuid) -> program_types.Program(option.Option(Snippet)) {
  program_types.Impure(
    program_types.SnippetEffect(snippet.GetSnippetById(
      id: uuid.to_bit_array(id),
      next: query_next,
    )),
  )
}

pub fn create(snippet snippet: Snippet) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.SnippetEffect(snippet.CreateSnippet(
      snippet: snippet,
      next: command_next,
    )),
  )
}

fn query_next(
  result: Result(option.Option(Snippet), error.DbQueryError),
) -> program_types.Program(option.Option(Snippet)) {
  case result {
    Ok(value) -> program_types.Pure(value)
    Error(err) -> program_types.Fail(error.QueryError(err))
  }
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}

pub fn update(snippet snippet: Snippet) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.SnippetEffect(snippet.UpdateSnippet(
      snippet: snippet,
      next: command_next,
    )),
  )
}
