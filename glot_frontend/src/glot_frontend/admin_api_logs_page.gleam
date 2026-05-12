import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/api_log_dto
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/duration_label
import glot_frontend/string_helpers
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

const page_limit = 25

pub type Model {
  Model(
    page: pagination_model.CursorPage(api_log_dto.ApiLogSummaryResponse),
    status: Status,
    error_filter: api_log_dto.ApiLogErrorFilter,
    request_id_filter: String,
    applied_request_id_filter: option.Option(uuid.Uuid),
    request_id_error: option.Option(String),
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type Msg {
  LogsLoaded(api.ApiResponse(api_log_dto.ListApiLogsResponse))
  ErrorFilterSelected(api_log_dto.ApiLogErrorFilter)
  RequestIdFilterChanged(String)
  ApplyFilters
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
      status: NotLoaded,
      error_filter: api_log_dto.AllApiLogs,
      request_id_filter: "",
      applied_request_id_filter: option.None,
      request_id_error: option.None,
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
    LogsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, page: response.page, status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load API logs.")),
          effect.none(),
        )
      }

    ErrorFilterSelected(filter) ->
      case filter == model.error_filter {
        True -> #(model, effect.none())
        False ->
          load_initial(
            Model(..model, error_filter: filter, request_id_error: option.None),
          )
      }

    RequestIdFilterChanged(value) -> #(
      Model(..model, request_id_filter: value, request_id_error: option.None),
      effect.none(),
    )

    ApplyFilters ->
      case parse_uuid_filter(model.request_id_filter, "Request ID") {
        Ok(request_id) ->
          load_initial(
            Model(
              ..model,
              applied_request_id_filter: request_id,
              request_id_error: option.None,
            ),
          )
        Error(message) -> #(
          Model(
            ..model,
            page: empty_page(),
            status: LoadError(message),
            request_id_error: option.Some(message),
          ),
          effect.none(),
        )
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

  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section(
        [attribute.class("app-panel admin-page admin-request-logs-page")],
        [
          html.div([attribute.class("admin-page__header")], [
            html.div([], [
              html.h2([attribute.class("admin-page__title")], [
                html.text("API logs"),
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
              html.h3([attribute.class("admin-page__group-title")], [
                html.text("Filters"),
              ]),
              html.p([attribute.class("admin-page__group-copy")], [
                html.text(filter_summary(model, rows)),
              ]),
            ]),
            html.div(
              [
                attribute.class(
                  "admin-page__policy admin-request-logs-page__filters",
                ),
              ],
              [
                html.div([attribute.class("admin-page__field-grid")], [
                  text_input(
                    label: "Request ID",
                    help: request_id_help(model),
                    value: model.request_id_filter,
                    on_input: RequestIdFilterChanged,
                  ),
                ]),
                html.div(
                  [attribute.class("admin-request-logs-page__filter-row")],
                  [
                    filter_group(title: "Error", chips: [
                      filter_chip(
                        "All",
                        model.error_filter == api_log_dto.AllApiLogs,
                        ErrorFilterSelected(api_log_dto.AllApiLogs),
                      ),
                      filter_chip(
                        "Errors only",
                        model.error_filter == api_log_dto.OnlyApiLogsWithErrors,
                        ErrorFilterSelected(api_log_dto.OnlyApiLogsWithErrors),
                      ),
                    ]),
                    html.div(
                      [attribute.class("admin-request-logs-page__apply")],
                      [
                        html.button(
                          [
                            attribute.class("admin-page__button"),
                            attribute.attribute("type", "button"),
                            event.on_click(ApplyFilters),
                          ],
                          [html.text("Apply")],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ]),
          html.div([attribute.class("admin-page__group")], [
            html.div([attribute.class("admin-page__group-header")], [
              html.h3([attribute.class("admin-page__group-title")], [
                html.text("Results"),
              ]),
            ]),
            status_view(model),
            logs_table(model, now),
          ]),
        ],
      ),
    ]),
  ])
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  load_page(
    Model(..model, page: empty_page(), status: Loading),
    pagination_model.InitialPage(limit: page_limit),
  )
}

fn load_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, Effect(Msg)) {
  #(
    model,
    api.get_admin_api_logs(
      api_log_dto.ListApiLogsRequest(
        pagination: pagination,
        request_id: model.applied_request_id_filter,
        error_filter: model.error_filter,
      ),
      LogsLoaded,
    ),
  )
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading API logs..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn logs_table(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.page)

  case rows, model.status {
    [], Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading API logs..."),
      ])

    [], _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No API logs matched these filters."),
      ])

    _, _ ->
      admin_table.table(log_columns(), {
        rows |> list.map(fn(log) { log_row(log, now) })
      })
  }
}

fn filter_group(
  title title: String,
  chips chips: List(Element(Msg)),
) -> Element(Msg) {
  html.div([attribute.class("admin-request-logs-page__filter-group")], [
    html.span([attribute.class("admin-jobs-page__filter-title")], [
      html.text(title),
    ]),
    html.div([attribute.class("admin-page__policy-actions")], chips),
  ])
}

fn filter_chip(label: String, selected: Bool, msg: Msg) -> Element(Msg) {
  let class_name = case selected {
    True -> "admin-page__chip admin-page__chip--selected"
    False -> "admin-page__chip"
  }

  html.button(
    [
      attribute.class(class_name),
      attribute.attribute("type", "button"),
      attribute.attribute("aria-pressed", bool_attribute(selected)),
      event.on_click(msg),
    ],
    [html.text(label)],
  )
}

fn pagination_button(label: String, msg: Msg, enabled: Bool) -> Element(Msg) {
  admin_ui.secondary_button(
    [
      attribute.attribute("type", "button"),
      attribute.disabled(!enabled),
      event.on_click(msg),
    ],
    label,
  )
}

fn text_input(
  label label: String,
  help help: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.input([
      attribute.type_("text"),
      attribute.class("admin-page__input"),
      attribute.value(value),
      attribute.attribute("placeholder", "UUID"),
      event.on_input(on_input),
    ]),
    html.span([attribute.class("admin-page__field-help")], [html.text(help)]),
  ])
}

fn log_row(
  log: api_log_dto.ApiLogSummaryResponse,
  now: Timestamp,
) -> Element(Msg) {
  admin_table.row([
    admin_table.cell(log_id_column(), [
      admin_table.stack([
        html.a(
          [
            attribute.class(
              "admin-table__value admin-table__value--primary admin-request-logs-page__link",
            ),
            route.href(route.AdminApiLog(log.id)),
          ],
          [
            html.text(string_helpers.truncate_stem_middle(
              uuid.to_string(log.id),
              18,
            )),
          ],
        ),
      ]),
    ]),
    admin_table.cell(when_column(), [
      admin_table.stack([
        html.span([attribute.class("admin-table__value--primary")], [
          html.text(timestamp_helpers.relative_label(log.created_at, now)),
        ]),
      ]),
    ]),
    admin_table.cell(action_column(), [admin_table.value(log.action)]),
    admin_table.cell(duration_column(), [
      html.text(duration_label.duration_in_ms_label(log.duration_ns)),
    ]),
    admin_table.cell(error_column(), [error_badge(log)]),
    admin_table.cell(open_column(), [
      admin_ui.secondary_link([route.href(route.AdminApiLog(log.id))], "Open"),
    ]),
  ])
}

fn log_columns() -> List(admin_table.Column) {
  [
    log_id_column(),
    when_column(),
    action_column(),
    duration_column(),
    error_column(),
    open_column(),
  ]
}

fn log_id_column() -> admin_table.Column {
  admin_table.column("Log ID")
}

fn when_column() -> admin_table.Column {
  admin_table.column("Created at")
}

fn action_column() -> admin_table.Column {
  admin_table.column("Action")
}

fn duration_column() -> admin_table.Column {
  admin_table.fit_column("Duration")
}

fn error_column() -> admin_table.Column {
  admin_table.fit_column("Error")
}

fn open_column() -> admin_table.Column {
  admin_table.action_column("Open")
}

fn error_text(log: api_log_dto.ApiLogSummaryResponse) -> String {
  case log.has_error {
    True -> "Error"
    False -> "None"
  }
}

fn error_badge(log: api_log_dto.ApiLogSummaryResponse) -> Element(Msg) {
  case log.has_error {
    True -> admin_ui.badge(error_text(log), admin_ui.DangerTone)
    False -> admin_ui.badge(error_text(log), admin_ui.SuccessTone)
  }
}

fn filter_summary(
  model: Model,
  rows: List(api_log_dto.ApiLogSummaryResponse),
) -> String {
  let base =
    int.to_string(list.length(rows))
    <> " API logs shown. "
    <> case model.error_filter {
      api_log_dto.AllApiLogs -> "All logs included."
      api_log_dto.OnlyApiLogsWithErrors -> "Errors only."
    }

  case model.applied_request_id_filter {
    option.Some(request_id) ->
      base <> " Request filter: " <> uuid.to_string(request_id)
    option.None -> base
  }
}

fn request_id_help(model: Model) -> String {
  case model.request_id_error {
    option.Some(message) -> message
    option.None ->
      case model.applied_request_id_filter {
        option.Some(request_id) -> "Filtering by " <> uuid.to_string(request_id)
        option.None -> "Leave blank to include all API request IDs."
      }
  }
}

fn parse_uuid_filter(
  value: String,
  label: String,
) -> Result(option.Option(uuid.Uuid), String) {
  let trimmed = string.trim(value)

  case trimmed == "" {
    True -> Ok(option.None)
    False ->
      case uuid.from_string(trimmed) {
        Ok(id) -> Ok(option.Some(id))
        Error(_) -> Error(label <> " must be a valid UUID.")
      }
  }
}

fn empty_page() -> pagination_model.CursorPage(
  api_log_dto.ApiLogSummaryResponse,
) {
  pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
}

fn can_go_previous(model: Model) -> Bool {
  case pagination_model.previous_cursor(model.page) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn can_go_next(model: Model) -> Bool {
  case pagination_model.next_cursor(model.page) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
