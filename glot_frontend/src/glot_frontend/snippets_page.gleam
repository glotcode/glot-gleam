import gleam/list
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/language
import glot_core/snippet/snippet_dto
import glot_frontend/api
import glot_frontend/route
import glot_frontend/top_bar
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem

const page_limit = 10

pub type Model {
  Model(
    snippets: List(snippet_dto.SnippetResponse),
    after: option.Option(String),
    before: option.Option(String),
    username: option.Option(String),
    previous_cursor: option.Option(String),
    next_cursor: option.Option(String),
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
      snippets: [],
      after: after,
      before: before,
      username: username,
      previous_cursor: option.None,
      next_cursor: option.None,
      state: Loading,
    )

  #(model, load_page(after, before, username))
}

pub type Msg {
  SnippetsLoaded(api.ApiResponse(snippet_dto.ListPublicSnippetsResponse))
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
          Model(
            ..model,
            snippets: response.snippets,
            previous_cursor: response.previous_cursor,
            next_cursor: response.next_cursor,
            state: Ready,
          ),
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
      case model.next_cursor {
        option.Some(next_cursor) -> #(
          model,
          navigate_to(option.Some(next_cursor), option.None, model.username),
        )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case model.previous_cursor {
        option.Some(previous_cursor) -> #(
          model,
          navigate_to(option.None, option.Some(previous_cursor), model.username),
        )
        option.None -> #(model, effect.none())
      }

    UsernameClicked(username) ->
      #(model, navigate_to(option.None, option.None, option.Some(username)))

    ClearUsernameFilterClicked ->
      #(model, navigate_to(option.None, option.None, option.None))
  }
}

pub fn view(
  model: Model,
  current_user_label: String,
  account_route: route.Route,
) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    top_bar.view(current_user_label, account_route),
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
              PreviousPageClicked,
              can_go_previous(model),
            ),
            pagination_button("Next", NextPageClicked, can_go_next(model)),
          ]),
        ]),
        status_view(model),
        snippets_table(model.snippets),
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
      after:,
      before:,
      usernames: usernames_from_filter(username),
      limit: page_limit,
    ),
    SnippetsLoaded,
  )
}

fn can_go_previous(model: Model) -> Bool {
  case model.previous_cursor {
    option.None -> False
    _ -> state_allows_pagination(model.state)
  }
}

fn can_go_next(model: Model) -> Bool {
  case model.next_cursor {
    option.Some(_) -> state_allows_pagination(model.state)
    option.None -> False
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
      case model.snippets {
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
          html.text("Filtered by @" <> username),
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
      [html.text(snippet.user.username)],
    ),
  ])
}

fn snippet_cell_link(
  class_name: String,
  destination: route.Route,
  label: String,
) -> Element(Msg) {
  html.a([attribute.class(class_name), route.href(destination)], [html.text(label)])
}

fn pagination_button(label: String, msg: Msg, enabled: Bool) -> Element(Msg) {
  html.button(
    [
      attribute.type_("button"),
      attribute.class("snippets-page__button"),
      attribute.disabled(!enabled),
      event.on_click(msg),
    ],
    [html.text(label)],
  )
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

fn timestamp_label(value: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
