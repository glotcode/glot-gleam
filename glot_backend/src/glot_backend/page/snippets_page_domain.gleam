import gleam/option
import glot_backend/domain/snippet/list_public_snippets_domain
import glot_backend/effect/error
import glot_backend/effect/error/request_error
import glot_backend/effect/program
import glot_backend/effect/total_program
import glot_backend/request_context
import glot_core/loadable
import glot_core/page/snippets

pub fn load_view_model(
  request_ctx: request_context.RequestContext,
  after: option.Option(String),
  before: option.Option(String),
  username: option.Option(String),
) -> total_program.TotalProgram(snippets.ViewModel) {
  let ctx = request_ctx.context
  let request = snippets.public_request(after:, before:, username:)
  let view_model_program =
    list_public_snippets_domain.list_public_snippets(request_ctx, request)
    |> program.map(fn(response) {
      snippets.ViewModel(
        page: loadable.Loaded(response.page),
        username: username,
        now: ctx.timestamp,
      )
    })

  total_program.from_program(view_model_program, fn(err) {
    snippets.ViewModel(
      page: loadable.LoadError(page_error_message(err)),
      username: username,
      now: ctx.timestamp,
    )
  })
}

fn page_error_message(err: error.Error) -> String {
  case err {
    error.RequestError(request_error.Validation(validation)) ->
      request_error.validation_message(validation)
    error.RequestError(request_error.TooManyRequests(_, _)) ->
      "Too many requests. Please try again."
    _ -> "Could not load snippets."
  }
}
