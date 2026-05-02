import gleam/erlang/process
import gleam/json
import gleam/option
import glot_backend/context
import glot_backend/domain/snippet/list_public_snippets_domain
import glot_backend/effect/error
import glot_backend/effect/interpreter
import glot_backend/effect/runtime
import glot_backend/worker/language_version_cache_worker
import glot_core/page/footer
import glot_core/page/snippets
import glot_core/page/top_bar
import glot_core/route
import lustre/attribute
import lustre/element
import lustre/element/html
import pog
import wisp.{type Response}

pub fn snippets_page(
  db: pog.Connection,
  ctx: context.Context,
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  after after: option.Option(String),
  before before: option.Option(String),
  username username: option.Option(String),
) -> Response {
  let view_model =
    load_view_model(
      db,
      ctx,
      language_version_cache_subject,
      after,
      before,
      username,
    )

  let html =
    html.html([attribute.lang("en")], [
      html.head([], [
        html.meta([attribute.charset("utf-8")]),
        html.meta([
          attribute.name("viewport"),
          attribute.content("width=device-width, initial-scale=1"),
        ]),
        html.title([], "glot.io - public snippets"),
        html.link([
          attribute.rel("stylesheet"),
          attribute.href("/static/styles.css"),
        ]),
        html.script(
          [
            attribute.type_("module"),
            attribute.src("/static/glot_frontend.js"),
          ],
          "",
        ),
      ]),
      html.body([], [
        html.div(
          [
            attribute.id("app"),
            attribute.attribute(
              "data-ssr",
              snippets.encode(view_model) |> json.to_string,
            ),
          ],
          [
            html.div([], [
              top_bar.view(initial_top_bar_model()),
              snippets.view(view_model),
              footer.view(account_route: route.Account),
            ]),
          ],
        ),
      ]),
    ])

  html
  |> element.to_document_string
  |> wisp.html_response(200)
}

fn load_view_model(
  db: pog.Connection,
  ctx: context.Context,
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
  after: option.Option(String),
  before: option.Option(String),
  username: option.Option(String),
) -> snippets.ViewModel {
  let request = snippets.public_request(after:, before:, username:)
  let runtime = runtime.new(db, language_version_cache_subject)
  let #(result, _) =
    list_public_snippets_domain.list_public_snippets(ctx, request)
    |> interpreter.run(runtime, ctx)

  case result {
    Ok(response) ->
      snippets.ViewModel(
        page: response.page,
        username: username,
        state: snippets.Ready,
      )
    Error(err) ->
      snippets.ViewModel(
        page: snippets.empty_page(),
        username: username,
        state: snippets.Error(page_error_message(err)),
      )
  }
}

fn page_error_message(err: error.Error) -> String {
  case err {
    error.ValidationError(message) -> message
    error.TooManyRequestsError(_, _) -> "Too many requests. Please try again."
    _ -> "Could not load snippets."
  }
}

fn initial_top_bar_model() -> top_bar.ViewModel(Nil) {
  top_bar.ViewModel(
    current_user_label: "Account",
    account_route: route.Account,
    search_query: "",
    selected_index: 0,
    open_msg: Nil,
    close_msg: Nil,
    search_changed: fn(_) { Nil },
    keydown: fn(_) { Nil },
    submit_msg: Nil,
    sections: top_bar.initial_home_sections(fn(_) { Nil }),
  )
}
