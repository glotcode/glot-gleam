import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/language
import glot_core/pagination_model
import glot_core/route
import glot_core/snippet/snippet_dto
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

const page_limit = 10

pub type State {
  Loading
  Ready
  Error(String)
}

pub type ViewModel {
  ViewModel(
    page: pagination_model.CursorPage(snippet_dto.SnippetResponse),
    username: option.Option(String),
    state: State,
  )
}

pub fn empty_page() -> pagination_model.CursorPage(snippet_dto.SnippetResponse) {
  pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
}

pub fn public_request(
  after after: option.Option(String),
  before before: option.Option(String),
  username username: option.Option(String),
) -> snippet_dto.ListPublicSnippetsRequest {
  snippet_dto.ListPublicSnippetsRequest(
    pagination: pagination_from_cursors(after, before),
    usernames: usernames_from_filter(username),
  )
}

pub fn decoder() -> decode.Decoder(ViewModel) {
  use page <- decode.field(
    "page",
    pagination_model.page_decoder("snippets", snippet_dto.response_decoder()),
  )
  use username <- decode.field("username", decode.optional(decode.string))
  use state <- decode.field("state", state_decoder())
  decode.success(ViewModel(page:, username:, state:))
}

pub fn encode(view_model: ViewModel) -> json.Json {
  json.object([
    #(
      "page",
      pagination_model.encode_page(
        view_model.page,
        "snippets",
        snippet_dto.encode_response,
      ),
    ),
    #("username", json.nullable(view_model.username, json.string)),
    #("state", encode_state(view_model.state)),
  ])
}

pub fn view(model: ViewModel) -> Element(msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel snippets-page")], [
        html.div([attribute.class("snippets-page__header")], [
          html.div([], [
            html.h2([attribute.class("snippets-page__title")], [
              html.text("Public snippets"),
            ]),
            active_filter_view(model.username),
          ]),
          html.div([attribute.class("snippets-page__pagination")], [
            pagination_button("Previous", previous_page_route(model)),
            pagination_button("Next", next_page_route(model)),
          ]),
        ]),
        status_view(model),
        snippets_table(pagination_model.items(model.page)),
      ]),
    ]),
  ])
}

fn pagination_from_cursors(
  after: option.Option(String),
  before: option.Option(String),
) -> pagination_model.CursorPagination {
  case after, before {
    option.Some(cursor), option.None ->
      pagination_model.AfterPage(
        cursor: pagination_model.from_string(cursor),
        limit: page_limit,
      )
    option.None, option.Some(cursor) ->
      pagination_model.BeforePage(
        cursor: pagination_model.from_string(cursor),
        limit: page_limit,
      )
    option.None, option.None -> pagination_model.InitialPage(limit: page_limit)
    option.Some(_), option.Some(_) ->
      pagination_model.InitialPage(limit: page_limit)
  }
}

fn state_decoder() -> decode.Decoder(State) {
  use kind <- decode.field("kind", decode.string)
  case kind {
    "loading" -> decode.success(Loading)
    "ready" -> decode.success(Ready)
    "error" -> {
      use message <- decode.field("message", decode.string)
      decode.success(Error(message))
    }
    _ -> decode.failure(Loading, "SnippetsPageState")
  }
}

fn encode_state(state: State) -> json.Json {
  case state {
    Loading -> json.object([#("kind", json.string("loading"))])
    Ready -> json.object([#("kind", json.string("ready"))])
    Error(message) ->
      json.object([
        #("kind", json.string("error")),
        #("message", json.string(message)),
      ])
  }
}

fn previous_page_route(model: ViewModel) -> option.Option(route.Route) {
  case pagination_model.previous_cursor(model.page) {
    option.Some(previous_cursor) ->
      option.Some(route.Snippets(
        after: option.None,
        before: option.Some(pagination_model.to_string(previous_cursor)),
        username: model.username,
      ))
    option.None -> option.None
  }
}

fn next_page_route(model: ViewModel) -> option.Option(route.Route) {
  case pagination_model.next_cursor(model.page) {
    option.Some(next_cursor) ->
      option.Some(route.Snippets(
        after: option.Some(pagination_model.to_string(next_cursor)),
        before: option.None,
        username: model.username,
      ))
    option.None -> option.None
  }
}

fn status_view(model: ViewModel) -> Element(msg) {
  case model.state {
    Loading ->
      html.p([attribute.class("snippets-page__status")], [
        html.text("Loading snippets..."),
      ])
    Ready ->
      case pagination_model.items(model.page) {
        [] ->
          html.p([attribute.class("snippets-page__status")], [
            html.text("No public snippets found."),
          ])
        _ -> html.p([attribute.class("snippets-page__status")], [])
      }
    Error(message) ->
      html.p(
        [attribute.class("snippets-page__status snippets-page__status--error")],
        [html.text(message)],
      )
  }
}

fn active_filter_view(username: option.Option(String)) -> Element(msg) {
  case username {
    option.Some(username) ->
      html.div([attribute.class("snippets-page__filters")], [
        html.span([attribute.class("snippets-page__filter")], [
          html.text("Filtered by @" <> truncate_username(username)),
        ]),
        html.a(
          [
            attribute.class("snippets-page__filter-clear"),
            route.href(route.Snippets(
              after: option.None,
              before: option.None,
              username: option.None,
            )),
          ],
          [html.text("Clear")],
        ),
      ])
    option.None -> html.div([], [])
  }
}

fn snippets_table(snippets: List(snippet_dto.SnippetResponse)) -> Element(msg) {
  html.div([attribute.class("snippets-table")], [
    html.div([attribute.class("snippets-table__head")], [
      html.span([attribute.class("snippets-table__heading")], [
        html.text("Language"),
      ]),
      html.span([attribute.class("snippets-table__heading")], [
        html.text("Title"),
      ]),
      html.span([attribute.class("snippets-table__heading")], [
        html.text("Created"),
      ]),
      html.span([attribute.class("snippets-table__heading")], [
        html.text("Username"),
      ]),
    ]),
    html.div([attribute.class("snippets-table__body")], {
      snippets |> list.map(snippet_row)
    }),
  ])
}

fn snippet_row(snippet: snippet_dto.SnippetResponse) -> Element(msg) {
  html.div([attribute.class("snippets-table__row")], [
    snippet_cell_link(
      "snippets-table__cell snippets-table__cell--language",
      route.Snippet(snippet.slug),
      language.name(snippet.data.language),
    ),
    snippet_cell_link(
      "snippets-table__cell snippets-table__cell--title",
      route.Snippet(snippet.slug),
      snippet.data.title,
    ),
    snippet_cell_link(
      "snippets-table__cell",
      route.Snippet(snippet.slug),
      timestamp_label(snippet.created_at),
    ),
    html.a(
      [
        attribute.class("snippets-table__cell snippets-table__username"),
        route.href(route.Snippets(
          after: option.None,
          before: option.None,
          username: option.Some(snippet.user.username),
        )),
      ],
      [html.text(truncate_username(snippet.user.username))],
    ),
  ])
}

fn snippet_cell_link(
  class_name: String,
  destination: route.Route,
  label: String,
) -> Element(msg) {
  html.a([attribute.class(class_name), route.href(destination)], [
    html.text(label),
  ])
}

fn pagination_button(
  label: String,
  destination: option.Option(route.Route),
) -> Element(msg) {
  case destination {
    option.Some(destination) ->
      html.a(
        [attribute.class("snippets-page__button"), route.href(destination)],
        [html.text(label)],
      )
    option.None ->
      html.button(
        [
          attribute.type_("button"),
          attribute.class("snippets-page__button"),
          attribute.disabled(True),
        ],
        [html.text(label)],
      )
  }
}

fn usernames_from_filter(username: option.Option(String)) -> List(String) {
  case username {
    option.Some(username) -> [username]
    option.None -> []
  }
}

fn truncate_username(username: String) -> String {
  truncate_stem_middle(username, 20)
}

fn truncate_stem_middle(stem: String, max_length: Int) -> String {
  case string.length(stem) > max_length {
    False -> stem
    True ->
      case max_length <= 4 {
        True -> string.slice(stem, 0, max_length)
        False -> {
          let visible_length = max_length - 3
          let prefix_length = visible_length - visible_length / 2
          let suffix_length = visible_length / 2

          string.slice(stem, 0, prefix_length)
          <> "..."
          <> string.slice(stem, -suffix_length, string.length(stem))
        }
      }
  }
}

fn timestamp_label(value: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
