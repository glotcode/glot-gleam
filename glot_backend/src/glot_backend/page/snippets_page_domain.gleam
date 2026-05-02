import gleam/option
import glot_backend/context
import glot_backend/domain/snippet/list_public_snippets_domain
import glot_backend/effect/error
import glot_backend/effect/program
import glot_backend/effect/total_program
import glot_core/page/snippets

pub fn load_view_model(
  ctx: context.Context,
  after: option.Option(String),
  before: option.Option(String),
  username: option.Option(String),
) -> total_program.TotalProgram(snippets.ViewModel) {
  let request = snippets.public_request(after:, before:, username:)
  let view_model_program =
    list_public_snippets_domain.list_public_snippets(ctx, request)
    |> program.map(fn(response) {
      snippets.ViewModel(
        page: response.page,
        username: username,
        state: snippets.Ready,
      )
    })

  total_program.from_program(view_model_program, fn(err) {
    snippets.ViewModel(
      page: snippets.empty_page(),
      username: username,
      state: snippets.Error(page_error_message(err)),
    )
  })
}

fn page_error_message(err: error.Error) -> String {
  case err {
    error.ValidationError(message) -> message
    error.TooManyRequestsError(_, _) -> "Too many requests. Please try again."
    _ -> "Could not load snippets."
  }
}
