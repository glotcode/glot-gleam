import gleam/option
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_backend/effect/snippet/snippet_algebra
import glot_core/snippet/snippet_model.{type HydratedSnippet, type Snippet}
import youid/uuid

pub fn get_by_id(
  id: uuid.Uuid,
) -> program_types.Program(option.Option(HydratedSnippet)) {
  program_types.Impure(
    program_types.SnippetEffect(snippet_algebra.GetSnippetById(
      id: uuid.to_bit_array(id),
      next: query_next,
    )),
  )
}

pub fn get_by_slug(
  slug: String,
) -> program_types.Program(option.Option(HydratedSnippet)) {
  program_types.Impure(
    program_types.SnippetEffect(snippet_algebra.GetSnippetBySlug(
      slug: slug,
      next: query_next,
    )),
  )
}

pub fn create(snippet snippet: Snippet) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.SnippetEffect(snippet_algebra.CreateSnippet(
      snippet: snippet,
      next: command_next,
    )),
  )
}

fn query_next(
  result: Result(option.Option(HydratedSnippet), error.DbQueryError),
) -> program_types.Program(option.Option(HydratedSnippet)) {
  case result {
    Ok(value) -> program_types.Pure(value)
    Error(err) -> program_types.Fail(error.QueryError(err))
  }
}

pub fn delete(id: uuid.Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.SnippetEffect(snippet_algebra.DeleteSnippet(
      id: uuid.to_bit_array(id),
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

pub fn update(snippet snippet: Snippet) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.SnippetEffect(snippet_algebra.UpdateSnippet(
      snippet: snippet,
      next: command_next,
    )),
  )
}
