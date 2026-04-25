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

const page_limit = 20

pub type Model {
  Model(
    snippets: List(snippet_dto.SnippetResponse),
    current_cursor: option.Option(String),
    previous_cursors: List(option.Option(String)),
    next_cursor: option.Option(String),
    state: State,
  )
}

pub type State {
  Loading
  Ready
  Error(String)
}

pub fn init() -> #(Model, Effect(Msg)) {
  let model =
    Model(
      snippets: [],
      current_cursor: option.None,
      previous_cursors: [],
      next_cursor: option.None,
      state: Loading,
    )

  #(model, load_page(option.None))
}

pub type Msg {
  SnippetsLoaded(api.ApiResponse(snippet_dto.ListPublicSnippetsResponse))
  NextPageClicked
  PreviousPageClicked
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SnippetsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            snippets: response.snippets,
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
          Model(
            ..model,
            current_cursor: option.Some(next_cursor),
            previous_cursors: [model.current_cursor, ..model.previous_cursors],
            state: Loading,
          ),
          load_page(option.Some(next_cursor)),
        )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case model.previous_cursors {
        [previous_cursor, ..rest] -> #(
          Model(
            ..model,
            current_cursor: previous_cursor,
            previous_cursors: rest,
            state: Loading,
          ),
          load_page(previous_cursor),
        )
        [] -> #(model, effect.none())
      }
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

fn load_page(cursor: option.Option(String)) -> Effect(Msg) {
  api.list_public_snippets(
    snippet_dto.ListPublicSnippetsRequest(cursor: cursor, limit: page_limit),
    SnippetsLoaded,
  )
}

fn can_go_previous(model: Model) -> Bool {
  case model.previous_cursors {
    [] -> False
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
  html.a(
    [
      attribute.class("snippets-table__row"),
      route.href(route.Snippet(snippet.slug)),
    ],
    [
      html.span(
        [attribute.class("snippets-table__cell snippets-table__cell--language")],
        [
          html.text(language.name(snippet.data.language)),
        ],
      ),
      html.span(
        [attribute.class("snippets-table__cell snippets-table__cell--title")],
        [
          html.text(snippet.data.title),
        ],
      ),
      html.span([attribute.class("snippets-table__cell")], [
        html.text(timestamp_label(snippet.created_at)),
      ]),
      html.span([attribute.class("snippets-table__cell")], [
        html.text(snippet.user.username),
      ]),
    ],
  )
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

fn timestamp_label(value: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
