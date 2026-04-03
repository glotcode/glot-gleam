import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet
import glot_core/snippet.{type Snippet} as _

pub fn create(snippet snippet: Snippet) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.SnippetEffect(snippet.CreateSnippet(
      snippet: snippet,
      next: command_next,
    )),
  )
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}
