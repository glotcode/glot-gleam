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
import glot_frontend/admin_cursor_page
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_core/loadable
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
    page: loadable.Loadable(
      pagination_model.CursorPage(snippet_dto.SnippetSummaryResponse),
    ),
    username_filter: String,
  )
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
  #(Model(page: loadable.NotLoaded, username_filter: ""), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case
    admin_cursor_page.ensure_loaded(
      model.page,
      load_page(
        Model(..model, page: loadable.Loading),
        pagination_model.InitialPage(limit: page_limit),
      ).1,
    )
  {
    #(page, next_effect) -> #(Model(..model, page: page), next_effect)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SnippetsLoaded(result) ->
      case result {
        _ -> #(
          Model(
            page: admin_cursor_page.page_from_response(
              result,
              fn(response) { response.page },
              "Could not load snippets.",
            ),
            username_filter: model.username_filter,
          ),
          effect.none(),
        )
      }

    UsernameFilterChanged(value) -> #(
      Model(..model, username_filter: value),
      effect.none(),
    )

    ApplyFilterClicked -> load_initial(model)

    ClearFilterClicked ->
      case model.username_filter == "" {
        True -> #(model, effect.none())
        False -> load_initial(Model(..model, username_filter: ""))
      }

    NextPageClicked ->
      admin_cursor_page.next_page(
        model,
        model.page,
        fn(model, page) { Model(..model, page: page) },
        load_page,
        page_limit,
      )

    PreviousPageClicked ->
      admin_cursor_page.previous_page(
        model,
        model.page,
        fn(model, page) { Model(..model, page: page) },
        load_page,
        page_limit,
      )
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(current_page(model))
  let count_text = int.to_string(list.length(rows)) <> " snippets shown."

  admin_ui.page_with_panel_class(
    panel_class: "admin-jobs-page",
    title: "Snippets",
    intro: "",
    actions: admin_ui.cursor_pagination_actions(
      current_page(model),
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
        admin_ui.loadable_status(model.page, "Loading snippets..."),
        snippets_table(model, now),
      ]),
    ],
  )
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  admin_cursor_page.load_initial(
    model,
    fn(model, page) { Model(..model, page: page) },
    load_page,
    page_limit,
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

fn snippets_table(model: Model, now: Timestamp) -> Element(Msg) {
  admin_ui.loadable_cursor_page_content(
    model.page,
    "Loading snippets...",
    "No snippets were returned.",
    fn(rows) {
      admin_table.table(snippet_columns(), {
        rows |> list.map(fn(snippet) { snippet_row(snippet, now) })
      })
    },
  )
}

fn current_page(
  model: Model,
) -> pagination_model.CursorPage(snippet_dto.SnippetSummaryResponse) {
  admin_cursor_page.current_page(model.page)
}

fn snippet_row(
  snippet: snippet_dto.SnippetSummaryResponse,
  now: Timestamp,
) -> Element(Msg) {
  admin_table.row([
    admin_table.value_cell(slug_column(), snippet.slug),
    admin_table.cell_with(
      language_column(),
      [
        attribute.class("admin-table__cell admin-table__cell--language"),
      ],
      [admin_table.value(language.name(snippet.language))],
    ),
    admin_table.cell_with(
      title_column(),
      [attribute.class("admin-table__cell admin-table__cell--title")],
      [
        admin_table.value(string_helpers.truncate_stem_middle(
          snippet.title,
          title_max_length,
        )),
      ],
    ),
    admin_table.value_cell(
      owner_column(),
      string_helpers.truncate_stem_middle(
        snippet.user.username,
        owner_max_length,
      ),
    ),
    admin_table.primary_meta_cell(
      updated_column(),
      timestamp_helpers.relative_label(snippet.updated_at, now),
      option.Some(int.to_string(snippet.file_count) <> " files"),
    ),
    admin_table.action_link_cell(
      open_column(),
      [route.href(route.Admin(route.AdminSnippet(snippet.slug)))],
      "Details",
    ),
  ])
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
  admin_table.open_column()
}

fn filter_username(value: String) -> option.Option(String) {
  case string.trim(value) {
    "" -> option.None
    username -> option.Some(username)
  }
}
