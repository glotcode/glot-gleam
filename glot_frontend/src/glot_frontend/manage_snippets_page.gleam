import gleam/list
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/language
import glot_core/pagination_model
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
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
    page: pagination_model.CursorPage(snippet_dto.SnippetResponse),
    after: option.Option(String),
    before: option.Option(String),
    state: State,
  )
}

pub type State {
  Loading
  Ready
  Deleting(String)
  Error(String)
}

pub fn init(
  after after: option.Option(String),
  before before: option.Option(String),
) -> #(Model, Effect(Msg)) {
  let model =
    Model(
      page: pagination_model.InitialCursorPage(
        items: [],
        next_cursor: option.None,
      ),
      after: after,
      before: before,
      state: Loading,
    )

  #(model, load_page(after, before))
}

pub type Msg {
  SnippetsLoaded(api.ApiResponse(snippet_dto.ListPublicSnippetsResponse))
  NextPageClicked
  PreviousPageClicked
  DeleteClicked(String)
  DeleteFinished(String, api.ApiResponse(Nil))
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
          Model(..model, state: Error("Could not load your snippets.")),
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
          ),
        )
        option.None -> #(model, effect.none())
      }

    DeleteClicked(slug) -> #(
      Model(..model, state: Deleting(slug)),
      api.delete_snippet(
        snippet_dto.DeleteSnippetRequest(slug: slug),
        fn(result) { DeleteFinished(slug, result) },
      ),
    )

    DeleteFinished(_, result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, state: Loading),
          load_page(model.after, model.before),
        )
        api.ApiFailure(error) -> #(
          Model(..model, state: Error(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, state: Error("Could not delete snippet.")),
          effect.none(),
        )
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
              html.text("Your snippets"),
            ]),
            html.p([attribute.class("snippets-page__status")], [
              html.text("Manage snippets created in your account."),
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
        snippets_table(model),
      ]),
    ]),
  ])
}

fn load_page(
  after: option.Option(String),
  before: option.Option(String),
) -> Effect(Msg) {
  api.list_session_snippets(
    snippet_dto.ListSessionSnippetsRequest(pagination: pagination_from_cursors(
      after,
      before,
    )),
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

fn state_allows_pagination(state: State) -> Bool {
  case state {
    Loading | Deleting(_) -> False
    Ready | Error(_) -> True
  }
}

fn status_view(model: Model) -> Element(Msg) {
  case model.state {
    Loading ->
      html.p([attribute.class("snippets-page__status")], [
        html.text("Loading your snippets..."),
      ])
    Ready ->
      case pagination_model.items(model.page) {
        [] ->
          html.p([attribute.class("snippets-page__status")], [
            html.text("You have not created any snippets yet."),
          ])
        _ -> html.p([attribute.class("snippets-page__status")], [])
      }
    Deleting(_) ->
      html.p([attribute.class("snippets-page__status")], [
        html.text("Deleting snippet..."),
      ])
    Error(message) ->
      html.p(
        [attribute.class("snippets-page__status snippets-page__status--error")],
        [html.text(message)],
      )
  }
}

fn snippets_table(model: Model) -> Element(Msg) {
  let deleting_slug = deleting_slug(model.state)

  html.div([attribute.class("snippets-table snippets-table--manage")], [
    html.div(
      [attribute.class("snippets-table__head snippets-table__head--manage")],
      [
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Language"),
        ]),
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Title"),
        ]),
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Visibility"),
        ]),
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Updated"),
        ]),
        html.span([attribute.class("snippets-table__heading")], [
          html.text("Actions"),
        ]),
      ],
    ),
    html.div([attribute.class("snippets-table__body")], {
      pagination_model.items(model.page)
      |> list.map(fn(snippet) { snippet_row(snippet, deleting_slug) })
    }),
  ])
}

fn snippet_row(
  snippet: snippet_dto.SnippetResponse,
  deleting_slug: option.Option(String),
) -> Element(Msg) {
  let is_deleting = deleting_slug == option.Some(snippet.slug)

  html.div(
    [attribute.class("snippets-table__row snippets-table__row--manage")],
    [
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
      html.span([attribute.class("snippets-table__cell")], [
        html.text(snippet_model.visibility_to_string(snippet.data.visibility)),
      ]),
      snippet_cell_link(
        "snippets-table__cell",
        route.Snippet(snippet.slug),
        timestamp_label(snippet.updated_at),
      ),
      html.div(
        [attribute.class("snippets-table__cell snippets-table__actions")],
        [
          html.a(
            [
              attribute.class("snippets-table__action-link"),
              route.href(route.Snippet(snippet.slug)),
            ],
            [html.text("Edit")],
          ),
          html.button(
            [
              attribute.type_("button"),
              attribute.class("snippets-table__action-button"),
              attribute.disabled(is_deleting),
              event.on_click(DeleteClicked(snippet.slug)),
            ],
            [
              html.text(case is_deleting {
                True -> "Deleting..."
                False -> "Delete"
              }),
            ],
          ),
        ],
      ),
    ],
  )
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
) -> Effect(Msg) {
  let #(path, query) =
    route.path_and_query(route.AccountSnippets(after:, before:))
  modem.push(path, query, option.None)
}

fn deleting_slug(state: State) -> option.Option(String) {
  case state {
    Deleting(slug) -> option.Some(slug)
    Loading | Ready | Error(_) -> option.None
  }
}

fn timestamp_label(value: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
