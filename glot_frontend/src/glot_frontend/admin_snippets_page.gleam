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
import glot_frontend/admin_table
import glot_frontend/admin_ui
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

  admin_ui.page_with_panel_class(
    panel_class: "admin-jobs-page",
    title: "Snippets",
    intro: "",
    actions:
      admin_ui.cursor_pagination_actions(
        model.page,
        PreviousPageClicked,
        NextPageClicked,
      ),
    content: [
      admin_ui.filter_section(
        copy: "Filter snippets by exact username.",
        content: admin_ui.filter_surface(
          [attribute.class("admin-snippets-page__filters")],
          [
            admin_ui.filter_field_grid([], [
              admin_ui.text_input(
                label: "Username",
                help: "Matches an exact account username.",
                value: model.username_filter,
                placeholder: "username",
                on_input: UsernameFilterChanged,
              ),
            ]),
            admin_ui.filter_actions([], [
              html.button(
                [
                  attribute.class("admin-page__button"),
                  attribute.type_("button"),
                  event.on_click(ApplyFilterClicked),
                ],
                [html.text("Apply")],
              ),
              admin_ui.secondary_button(
                [
                  attribute.type_("button"),
                  attribute.disabled(model.username_filter == ""),
                  event.on_click(ClearFilterClicked),
                ],
                "Clear",
              ),
            ]),
          ],
        ),
      ),
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
    ],
  )
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
      admin_table.table(snippet_columns(), {
        rows |> list.map(fn(snippet) { snippet_row(snippet, now) })
      })
  }
}

fn snippet_row(
  snippet: snippet_dto.SnippetSummaryResponse,
  now: Timestamp,
) -> Element(Msg) {
  admin_table.row([
    cell(slug_column(), snippet.slug, []),
    cell(language_column(), language.name(snippet.language), [
      attribute.class("admin-table__cell admin-table__cell--language"),
    ]),
    cell(
      title_column(),
      string_helpers.truncate_stem_middle(snippet.title, title_max_length),
      [
        attribute.class("admin-table__cell admin-table__cell--title"),
      ],
    ),
    cell(
      owner_column(),
      string_helpers.truncate_stem_middle(
        snippet.user.username,
        owner_max_length,
      ),
      [
        attribute.class("admin-table__cell"),
      ],
    ),
    admin_table.cell(updated_column(), [
      admin_table.stack([
        admin_table.value(timestamp_helpers.relative_label(
          snippet.updated_at,
          now,
        )),
        admin_table.meta(int.to_string(snippet.file_count) <> " files"),
      ]),
    ]),
    admin_table.cell(open_column(), [
      admin_ui.secondary_link(
        [route.href(route.AdminSnippet(snippet.slug))],
        "Details",
      ),
    ]),
  ])
}

fn cell(
  column: admin_table.Column,
  value: String,
  attrs: List(attribute.Attribute(Msg)),
) -> Element(Msg) {
  admin_table.cell_with(column, attrs, [admin_table.value(value)])
}

fn snippet_columns() -> List(admin_table.Column) {
  [
    slug_column(),
    language_column(),
    title_column(),
    owner_column(),
    updated_column(),
    open_column(),
  ]
}

fn slug_column() -> admin_table.Column {
  admin_table.column("Slug")
}

fn language_column() -> admin_table.Column {
  admin_table.fit_column("Language")
}

fn title_column() -> admin_table.Column {
  admin_table.column("Title")
}

fn owner_column() -> admin_table.Column {
  admin_table.column("Owner")
}

fn updated_column() -> admin_table.Column {
  admin_table.column("Updated at")
}

fn open_column() -> admin_table.Column {
  admin_table.action_column("Open")
}

fn filter_username(value: String) -> option.Option(String) {
  case string.trim(value) {
    "" -> option.None
    username -> option.Some(username)
  }
}
