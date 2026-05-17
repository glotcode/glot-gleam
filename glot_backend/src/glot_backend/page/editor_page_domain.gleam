import glot_backend/context
import glot_backend/domain/snippet/get_snippet_domain
import glot_backend/effect/error
import glot_backend/effect/error/request_error
import glot_backend/effect/error/resource_error
import glot_backend/effect/program
import glot_backend/effect/total_program
import glot_core/page/editor
import glot_core/snippet/snippet_dto

pub fn load_new_view_model(
  language_slug: String,
) -> total_program.TotalProgram(editor.ViewModel) {
  total_program.succeed(editor.new(language_slug))
}

pub fn load_existing_view_model(
  ctx: context.Context,
  slug: String,
) -> total_program.TotalProgram(editor.ViewModel) {
  get_snippet_domain.get_snippet(ctx, snippet_dto.GetSnippetRequest(slug: slug))
  |> program.map(editor.from_snippet)
  |> total_program.from_program(fn(err) {
    editor.LoadError(page_error_message(err))
  })
}

fn page_error_message(err: error.Error) -> String {
  case err {
    error.ResourceError(resource_error.SnippetNotFound) -> "Snippet not found."
    error.RequestError(request_error.Validation(validation)) ->
      request_error.validation_message(validation)
    error.RequestError(request_error.TooManyRequests(_, _)) ->
      "Too many requests. Please try again."
    _ -> "Could not load snippet."
  }
}
