import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/job_log_dto
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/duration_label
import glot_frontend/loadable
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
    page: loadable.Loadable(pagination_model.CursorPage(job_log_dto.JobLogResponse)),
    error_filter: job_log_dto.JobLogErrorFilter,
    request_id_filter: String,
    job_id_filter: String,
    applied_request_id_filter: option.Option(uuid.Uuid),
    applied_job_id_filter: option.Option(uuid.Uuid),
    request_id_error: option.Option(String),
    job_id_error: option.Option(String),
  )
}

pub type Msg {
  LogsLoaded(api.ApiResponse(job_log_dto.ListJobLogsResponse))
  ErrorFilterSelected(job_log_dto.JobLogErrorFilter)
  RequestIdFilterChanged(String)
  JobIdFilterChanged(String)
  ApplyFilters
  NextPageClicked
  PreviousPageClicked
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      page: loadable.NotLoaded,
      error_filter: job_log_dto.AllJobLogs,
      request_id_filter: "",
      job_id_filter: "",
      applied_request_id_filter: option.None,
      applied_job_id_filter: option.None,
      request_id_error: option.None,
      job_id_error: option.None,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.page {
    loadable.NotLoaded -> load_initial(model)
    loadable.Loading | loadable.Loaded(_) | loadable.LoadError(_) ->
      #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LogsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, page: loadable.Loaded(response.page)),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, page: loadable.LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, page: loadable.LoadError("Could not load job logs.")),
          effect.none(),
        )
      }

    ErrorFilterSelected(filter) ->
      case filter == model.error_filter {
        True -> #(model, effect.none())
        False ->
          load_initial(
            Model(
              ..model,
              error_filter: filter,
              request_id_error: option.None,
              job_id_error: option.None,
            ),
          )
      }

    RequestIdFilterChanged(value) -> #(
      Model(..model, request_id_filter: value, request_id_error: option.None),
      effect.none(),
    )

    JobIdFilterChanged(value) -> #(
      Model(..model, job_id_filter: value, job_id_error: option.None),
      effect.none(),
    )

    ApplyFilters ->
      case parse_uuid_filter(model.request_id_filter, "Request ID") {
        Ok(request_id) ->
          case parse_uuid_filter(model.job_id_filter, "Job ID") {
            Ok(job_id) ->
              load_initial(
                Model(
                  ..model,
                  applied_request_id_filter: request_id,
                  applied_job_id_filter: job_id,
                  request_id_error: option.None,
                  job_id_error: option.None,
                ),
              )
            Error(message) -> #(
              Model(
                ..model,
                page: loadable.LoadError(message),
                job_id_error: option.Some(message),
              ),
              effect.none(),
            )
          }
        Error(message) -> #(
          Model(
            ..model,
            page: loadable.LoadError(message),
            request_id_error: option.Some(message),
          ),
          effect.none(),
        )
      }

    NextPageClicked ->
      case pagination_model.next_cursor(current_page(model)) {
        option.Some(cursor) ->
          load_page(
            Model(..model, page: loadable.Loading),
            pagination_model.AfterPage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case pagination_model.previous_cursor(current_page(model)) {
        option.Some(cursor) ->
          load_page(
            Model(..model, page: loadable.Loading),
            pagination_model.BeforePage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(current_page(model))

  admin_ui.page_with_panel_class(
    panel_class: "admin-job-logs-page",
    title: "Job logs",
    intro: "",
    actions: [
      pagination_button("Previous", PreviousPageClicked, can_go_previous(model)),
      pagination_button("Next", NextPageClicked, can_go_next(model)),
    ],
    content: [
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
                  "admin-page__policy admin-job-logs-page__filters",
                ),
              ],
              [
                html.div(
                  [
                    attribute.class(
                      "admin-page__field-grid admin-job-logs-page__field-grid",
                    ),
                  ],
                  [
                    text_input(
                      label: "Request ID",
                      help: request_id_help(model),
                      value: model.request_id_filter,
                      on_input: RequestIdFilterChanged,
                    ),
                    text_input(
                      label: "Job ID",
                      help: job_id_help(model),
                      value: model.job_id_filter,
                      on_input: JobIdFilterChanged,
                    ),
                  ],
                ),
                html.div([attribute.class("admin-job-logs-page__filter-row")], [
                  filter_group(title: "Error", chips: [
                    filter_chip(
                      "All",
                      model.error_filter == job_log_dto.AllJobLogs,
                      ErrorFilterSelected(job_log_dto.AllJobLogs),
                    ),
                    filter_chip(
                      "Errors only",
                      model.error_filter == job_log_dto.OnlyJobLogsWithErrors,
                      ErrorFilterSelected(job_log_dto.OnlyJobLogsWithErrors),
                    ),
                  ]),
                  html.div([attribute.class("admin-job-logs-page__apply")], [
                    html.button(
                      [
                        attribute.class("admin-page__button"),
                        attribute.attribute("type", "button"),
                        event.on_click(ApplyFilters),
                      ],
                      [html.text("Apply")],
                    ),
                  ]),
                ]),
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
  )
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  load_page(
    Model(..model, page: loadable.Loading),
    pagination_model.InitialPage(limit: page_limit),
  )
}

fn load_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, Effect(Msg)) {
  #(
    model,
    api.get_admin_job_logs(
      job_log_dto.ListJobLogsRequest(
        pagination: pagination,
        request_id: model.applied_request_id_filter,
        job_id: model.applied_job_id_filter,
        error_filter: model.error_filter,
      ),
      LogsLoaded,
    ),
  )
}

fn status_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.page,
    admin_ui.status(""),
    admin_ui.status("Loading job logs..."),
    fn(_) { admin_ui.status("") },
    admin_ui.error_status,
  )
}

fn logs_table(model: Model, now: Timestamp) -> Element(Msg) {
  loadable.fold(
    model.page,
    admin_ui.empty_state("No job logs matched these filters."),
    admin_ui.empty_state("Loading job logs..."),
    fn(page) {
      case pagination_model.items(page) {
        [] -> admin_ui.empty_state("No job logs matched these filters.")
        rows ->
          admin_table.table(log_columns(), {
            rows |> list.map(fn(log) { log_row(log, now) })
          })
      }
    },
    fn(_) { admin_ui.empty_state("No job logs matched these filters.") },
  )
}

fn current_page(
  model: Model,
) -> pagination_model.CursorPage(job_log_dto.JobLogResponse) {
  case model.page {
    loadable.Loaded(page) -> page
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) -> empty_page()
  }
}

fn filter_group(
  title title: String,
  chips chips: List(Element(Msg)),
) -> Element(Msg) {
  html.div([attribute.class("admin-job-logs-page__filter-group")], [
    html.span([attribute.class("admin-jobs-page__filter-title")], [
      html.text(title),
    ]),
    html.div([attribute.class("admin-page__actions")], chips),
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

fn log_row(log: job_log_dto.JobLogResponse, now: Timestamp) -> Element(Msg) {
  admin_table.row([
    admin_table.cell(log_id_column(), [
      admin_table.stack([
        html.a(
          [
            attribute.class(
              "admin-table__value admin-table__value--primary admin-job-logs-page__link",
            ),
            route.href(route.AdminJobLog(log.id)),
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
      html.span([attribute.class("admin-table__value--primary")], [
        html.text(timestamp_helpers.relative_label(log.created_at, now)),
      ]),
    ]),
    admin_table.cell(job_type_column(), [
      admin_table.stack([
        html.span([attribute.class("admin-table__value--primary")], [
          html.text(log.job_type),
        ]),
      ]),
    ]),
    admin_table.cell(attempt_column(), [html.text(int.to_string(log.attempt))]),
    admin_table.cell(duration_column(), [
      html.text(duration_label.duration_in_ms_label(log.duration_ns)),
    ]),
    admin_table.cell(error_column(), [error_badge(log)]),
    admin_table.cell(open_column(), [
      admin_ui.secondary_link([route.href(route.AdminJobLog(log.id))], "Open"),
    ]),
  ])
}

fn log_columns() -> List(admin_table.Column) {
  [
    log_id_column(),
    when_column(),
    job_type_column(),
    attempt_column(),
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

fn job_type_column() -> admin_table.Column {
  admin_table.column("Job type")
}

fn attempt_column() -> admin_table.Column {
  admin_table.fit_column("Attempt")
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

fn filter_summary(
  model: Model,
  rows: List(job_log_dto.JobLogResponse),
) -> String {
  let count_text = int.to_string(list.length(rows)) <> " job logs shown."
  let error_text = case model.error_filter {
    job_log_dto.AllJobLogs -> " All logs included."
    job_log_dto.OnlyJobLogsWithErrors -> " Errors only."
  }
  let request_text = case model.applied_request_id_filter {
    option.Some(request_id) -> " Request: " <> uuid.to_string(request_id) <> "."
    option.None -> ""
  }
  let job_text = case model.applied_job_id_filter {
    option.Some(job_id) -> " Job: " <> uuid.to_string(job_id) <> "."
    option.None -> ""
  }

  count_text <> error_text <> request_text <> job_text
}

fn request_id_help(model: Model) -> String {
  case model.request_id_error {
    option.Some(message) -> message
    option.None ->
      case model.applied_request_id_filter {
        option.Some(request_id) -> "Filtering by " <> uuid.to_string(request_id)
        option.None -> "Leave blank to include all request IDs."
      }
  }
}

fn job_id_help(model: Model) -> String {
  case model.job_id_error {
    option.Some(message) -> message
    option.None ->
      case model.applied_job_id_filter {
        option.Some(job_id) -> "Filtering by " <> uuid.to_string(job_id)
        option.None -> "Leave blank to include all job IDs."
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

fn empty_page() -> pagination_model.CursorPage(job_log_dto.JobLogResponse) {
  pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
}

fn can_go_previous(model: Model) -> Bool {
  case pagination_model.previous_cursor(current_page(model)) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn can_go_next(model: Model) -> Bool {
  case pagination_model.next_cursor(current_page(model)) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn error_badge(log: job_log_dto.JobLogResponse) -> Element(Msg) {
  case log.has_error {
    True -> admin_ui.badge(error_text(log), admin_ui.DangerTone)
    False -> admin_ui.badge(error_text(log), admin_ui.SuccessTone)
  }
}

fn error_text(log: job_log_dto.JobLogResponse) -> String {
  case log.has_error {
    True -> "Error"
    False -> "None"
  }
}

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
