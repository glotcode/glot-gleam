import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/snippet_dto
import glot_core/helpers/timestamp_helpers
import glot_core/language
import glot_core/pagination_model
import glot_core/route
import glot_frontend/api
import glot_frontend/string_helpers
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

const page_limit = 25

const title_max_length = 32

const owner_max_length = 20

pub type Model {
  Model(
    page: pagination_model.CursorPage(snippet_dto.SnippetSummaryResponse),
    username_filter: String,
    status: Status,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type Msg {
  SnippetsLoaded(api.ApiResponse(snippet_dto.ListSnippetsResponse))
  UsernameFilterChanged(String)
  ApplyFilterClicked
  ClearFilterClicked
  NextPageClicked
  PreviousPageClicked
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      page: pagination_model.InitialCursorPage(
        items: [],
        next_cursor: option.None,
      ),
      username_filter: "",
      status: NotLoaded,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> load_initial(model)
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SnippetsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            page: response.page,
            username_filter: model.username_filter,
            status: Ready,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load snippets.")),
          effect.none(),
        )
      }

    UsernameFilterChanged(value) -> #(
      Model(..model, username_filter: value),
      effect.none(),
    )

    ApplyFilterClicked -> load_initial(Model(..model, status: Loading))

    ClearFilterClicked ->
      case model.username_filter == "" {
        True -> #(model, effect.none())
        False ->
          load_initial(Model(..model, username_filter: "", status: Loading))
      }

    NextPageClicked ->
      case pagination_model.next_cursor(model.page) {
        option.Some(cursor) ->
          load_page(
            Model(..model, status: Loading),
            pagination_model.AfterPage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case pagination_model.previous_cursor(model.page) {
        option.Some(cursor) ->
          load_page(
            Model(..model, status: Loading),
            pagination_model.BeforePage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.page)
  let count_text = int.to_string(list.length(rows)) <> " snippets shown."

  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-jobs-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Snippets"),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            pagination_button(
              "Previous",
              PreviousPageClicked,
              can_go_previous(model),
            ),
            pagination_button("Next", NextPageClicked, can_go_next(model)),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.div([], [
              html.h3([attribute.class("admin-page__group-title")], [
                html.text("Filters"),
              ]),
              html.p([attribute.class("admin-page__group-copy")], [
                html.text("Filter snippets by exact username."),
              ]),
            ]),
          ]),
          html.div(
            [attribute.class("admin-page__policy admin-snippets-page__filters")],
            [
              html.input([
                attribute.class("admin-page__input"),
                attribute.type_("text"),
                attribute.placeholder("username"),
                attribute.value(model.username_filter),
                event.on_input(UsernameFilterChanged),
              ]),
              html.button(
                [
                  attribute.class("admin-page__button"),
                  attribute.type_("button"),
                  event.on_click(ApplyFilterClicked),
                ],
                [html.text("Apply")],
              ),
              html.button(
                [
                  attribute.class(
                    "admin-page__button admin-page__button--secondary",
                  ),
                  attribute.type_("button"),
                  attribute.disabled(model.username_filter == ""),
                  event.on_click(ClearFilterClicked),
                ],
                [html.text("Clear")],
              ),
            ],
          ),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.div([], [
              html.h3([attribute.class("admin-page__group-title")], [
                html.text("Directory"),
              ]),
              html.p([attribute.class("admin-page__group-copy")], [
                html.text(count_text),
              ]),
            ]),
          ]),
          status_view(model),
          snippets_table(model, now),
        ]),
      ]),
    ]),
  ])
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  let reset_page =
    pagination_model.InitialCursorPage(items: [], next_cursor: option.None)

  load_page(
    Model(..model, page: reset_page, status: Loading),
    pagination_model.InitialPage(limit: page_limit),
  )
}

fn load_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, Effect(Msg)) {
  #(
    model,
    api.get_admin_snippets(
      snippet_dto.ListSnippetsRequest(
        pagination: pagination,
        username: filter_username(model.username_filter),
      ),
      SnippetsLoaded,
    ),
  )
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [
        html.text(""),
      ])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading snippets..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn snippets_table(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.page)

  case rows, model.status {
    [], Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading snippets..."),
      ])
    [], _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No snippets were returned."),
      ])
    _, _ ->
      html.div([attribute.class("admin-data-table__wrap")], [
        html.table([attribute.class("admin-data-table")], [
          html.thead([], [
            html.tr([], [
              table_heading("Slug"),
              table_heading("Language"),
              table_heading("Title"),
              table_heading("Owner"),
              table_heading("Updated"),
              table_heading("Open"),
            ]),
          ]),
          html.tbody([], {
            rows |> list.map(fn(snippet) { snippet_row(snippet, now) })
          }),
        ]),
      ])
  }
}

fn snippet_row(
  snippet: snippet_dto.SnippetSummaryResponse,
  now: Timestamp,
) -> Element(Msg) {
  html.tr([], [
    cell("Slug", snippet.slug, [attribute.class("admin-data-table__cell")]),
    cell("Language", language.name(snippet.language), [
      attribute.class("admin-data-table__cell admin-data-table__cell--language"),
    ]),
    cell(
      "Title",
      string_helpers.truncate_stem_middle(snippet.title, title_max_length),
      [
        attribute.class("admin-data-table__cell admin-data-table__cell--title"),
      ],
    ),
    cell(
      "Owner",
      string_helpers.truncate_stem_middle(
        snippet.user.username,
        owner_max_length,
      ),
      [
        attribute.class("admin-data-table__cell"),
      ],
    ),
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Updated"),
      html.div([attribute.class("jobs-table__stack")], [
        html.span([attribute.class("admin-data-table__value")], [
          html.text(timestamp_helpers.relative_label(snippet.updated_at, now)),
        ]),
        html.span([attribute.class("jobs-table__meta")], [
          html.text(int.to_string(snippet.file_count) <> " files"),
        ]),
      ]),
    ]),
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Open"),
      html.a(
        [
          attribute.class("admin-page__button admin-page__button--secondary"),
          route.href(route.AdminSnippet(snippet.slug)),
        ],
        [html.text("Details")],
      ),
    ]),
  ])
}

fn cell(
  label_text: String,
  value: String,
  attrs: List(attribute.Attribute(Msg)),
) -> Element(Msg) {
  html.td(attrs, [
    cell_label(label_text),
    html.span([attribute.class("admin-data-table__value")], [
      html.text(value),
    ]),
  ])
}

fn cell_label(text: String) -> Element(Msg) {
  html.span([attribute.class("admin-data-table__label")], [html.text(text)])
}

fn table_heading(text: String) -> Element(Msg) {
  html.th([attribute.class("admin-data-table__heading")], [html.text(text)])
}

fn filter_username(value: String) -> option.Option(String) {
  case string.trim(value) {
    "" -> option.None
    username -> option.Some(username)
  }
}

fn can_go_next(model: Model) -> Bool {
  case pagination_model.next_cursor(model.page) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn can_go_previous(model: Model) -> Bool {
  case pagination_model.previous_cursor(model.page) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn pagination_button(text: String, msg: Msg, enabled: Bool) -> Element(Msg) {
  html.button(
    [
      attribute.class("admin-page__button admin-page__button--secondary"),
      attribute.type_("button"),
      attribute.disabled(!enabled),
      event.on_click(msg),
    ],
    [html.text(text)],
  )
}
