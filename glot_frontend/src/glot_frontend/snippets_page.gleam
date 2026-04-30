import gleam/list
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/language
import glot_core/pagination_model
import glot_core/snippet/snippet_dto
import glot_frontend/api
import glot_frontend/route
import glot_frontend/string_helpers
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem

const page_limit = 10

pub type Model {
  Model(
    page: pagination_model.CursorPage(snippet_dto.SnippetResponse),
    after: option.Option(String),
    before: option.Option(String),
    username: option.Option(String),
    state: State,
  )
}

pub type State {
  Loading
  Ready
  Error(String)
}

pub fn init(
  after after: option.Option(String),
  before before: option.Option(String),
  username username: option.Option(String),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      page: pagination_model.InitialCursorPage(
        items: [],
        next_cursor: option.None,
      ),
      after: after,
      before: before,
      username: username,
      state: Loading,
    )

  #(model, load_page(after, before, username))
}

pub type Msg {
  SnippetsLoaded(api.ApiResponse(snippet_dto.ListSnippetsResponse))
  NextPageClicked
  PreviousPageClicked
  UsernameClicked(String)
  ClearUsernameFilterClicked
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SnippetsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, page: response.page, state: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, state: Error(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, state: Error("Could not load snippets.")),
          effect.none(),
        )
      }

    NextPageClicked ->
      case pagination_model.next_cursor(model.page) {
        option.Some(next_cursor) -> #(
          model,
          navigate_to(
            option.Some(pagination_model.to_string(next_cursor)),
            option.None,
            model.username,
          ),
        )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case pagination_model.previous_cursor(model.page) {
        option.Some(previous_cursor) -> #(
          model,
          navigate_to(
            option.None,
            option.Some(pagination_model.to_string(previous_cursor)),
            model.username,
          ),
        )
        option.None -> #(model, effect.none())
      }

    UsernameClicked(username) -> #(
      model,
      navigate_to(option.None, option.None, option.Some(username)),
    )

    ClearUsernameFilterClicked -> #(
      model,
      navigate_to(option.None, option.None, option.None),
    )
  }
}

pub fn view(model: Model) -> Element(Msg) {
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
            pagination_button(
              "Previous",
              previous_page_route(model),
              PreviousPageClicked,
              can_go_previous(model),
            ),
            pagination_button(
              "Next",
              next_page_route(model),
              NextPageClicked,
              can_go_next(model),
            ),
          ]),
        ]),
        status_view(model),
        snippets_table(pagination_model.items(model.page)),
      ]),
    ]),
  ])
}

fn load_page(
  after: option.Option(String),
  before: option.Option(String),
  username: option.Option(String),
) -> Effect(Msg) {
  api.list_public_snippets(
    snippet_dto.ListPublicSnippetsRequest(
      pagination: pagination_from_cursors(after, before),
      usernames: usernames_from_filter(username),
    ),
    SnippetsLoaded,
  )
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

fn can_go_previous(model: Model) -> Bool {
  case pagination_model.previous_cursor(model.page) {
    option.None -> False
    _ -> state_allows_pagination(model.state)
  }
}

fn can_go_next(model: Model) -> Bool {
  case pagination_model.next_cursor(model.page) {
    option.Some(_) -> state_allows_pagination(model.state)
    option.None -> False
  }
}

fn previous_page_route(model: Model) -> option.Option(route.Route) {
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

fn next_page_route(model: Model) -> option.Option(route.Route) {
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

fn state_allows_pagination(state: State) -> Bool {
  case state {
    Loading -> False
    Ready | Error(_) -> True
  }
}

fn status_view(model: Model) -> Element(Msg) {
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

fn active_filter_view(username: option.Option(String)) -> Element(Msg) {
  case username {
    option.Some(username) ->
      html.div([attribute.class("snippets-page__filters")], [
        html.span([attribute.class("snippets-page__filter")], [
          html.text("Filtered by @" <> truncate_username(username)),
        ]),
        html.button(
          [
            attribute.type_("button"),
            attribute.class("snippets-page__filter-clear"),
            event.on_click(ClearUsernameFilterClicked),
          ],
          [html.text("Clear")],
        ),
      ])
    option.None -> html.div([], [])
  }
}

fn snippets_table(snippets: List(snippet_dto.SnippetResponse)) -> Element(Msg) {
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

fn snippet_row(snippet: snippet_dto.SnippetResponse) -> Element(Msg) {
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
    html.button(
      [
        attribute.type_("button"),
        attribute.class("snippets-table__cell snippets-table__username"),
        event.on_click(UsernameClicked(snippet.user.username)),
      ],
      [html.text(truncate_username(snippet.user.username))],
    ),
  ])
}

fn snippet_cell_link(
  class_name: String,
  destination: route.Route,
  label: String,
) -> Element(Msg) {
  html.a([attribute.class(class_name), route.href(destination)], [
    html.text(label),
  ])
}

fn pagination_button(
  label: String,
  destination: option.Option(route.Route),
  msg: Msg,
  enabled: Bool,
) -> Element(Msg) {
  case destination, enabled {
    option.Some(destination), True ->
      html.a(
        [
          attribute.class("snippets-page__button"),
          route.href(destination),
          event.prevent_default(event.on_click(msg)),
        ],
        [html.text(label)],
      )
    _, _ ->
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

fn navigate_to(
  after: option.Option(String),
  before: option.Option(String),
  username: option.Option(String),
) -> Effect(Msg) {
  let #(path, query) =
    route.path_and_query(route.Snippets(after:, before:, username:))
  modem.push(path, query, option.None)
}

fn usernames_from_filter(username: option.Option(String)) -> List(String) {
  case username {
    option.Some(username) -> [username]
    option.None -> []
  }
}

fn truncate_username(username: String) -> String {
  string_helpers.truncate_stem_middle(username, 20)
}

fn timestamp_label(value: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
