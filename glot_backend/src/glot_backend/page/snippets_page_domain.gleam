import gleam/option
import glot_backend/snippet/domain/list_public as list_public_snippets_domain
import glot_backend/system/effect/error
import glot_backend/system/effect/error/request_error
import glot_backend/system/effect/program
import glot_backend/system/effect/total_program
import glot_backend/system/request/hydrated_context as request_context
import glot_core/loadable
import glot_web/page/snippets

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
