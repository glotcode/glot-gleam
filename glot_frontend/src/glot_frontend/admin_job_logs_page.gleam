import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/job_log_dto
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
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
    page: pagination_model.CursorPage(job_log_dto.JobLogResponse),
    status: Status,
    error_filter: job_log_dto.JobLogErrorFilter,
    request_id_filter: String,
    job_id_filter: String,
    applied_request_id_filter: option.Option(uuid.Uuid),
    applied_job_id_filter: option.Option(uuid.Uuid),
    request_id_error: option.Option(String),
    job_id_error: option.Option(String),
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
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
      page: empty_page(),
      status: NotLoaded,
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
          Model(..model, status: LoadError("Could not load job logs.")),
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
                page: empty_page(),
                status: LoadError(message),
                job_id_error: option.Some(message),
              ),
              effect.none(),
            )
          }
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
        [attribute.class("app-panel admin-page admin-job-logs-page")],
        [
          html.div([attribute.class("admin-page__header")], [
            html.div([], [
              html.h2([attribute.class("admin-page__title")], [
                html.text("Job logs"),
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
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading job logs..."),
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
        html.text("Loading job logs..."),
      ])

    [], _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No job logs matched these filters."),
      ])

    _, _ ->
      html.div([attribute.class("admin-job-logs-table")], [
        html.table([attribute.class("admin-job-logs-table__element")], [
          html.thead([], [
            html.tr([], [
              table_heading("Log ID"),
              table_heading("When"),
              table_heading("Job type"),
              table_heading("Attempt"),
              table_heading("Duration"),
              table_heading("Error"),
              table_heading("Open"),
            ]),
          ]),
          html.tbody([], { rows |> list.map(fn(log) { log_row(log, now) }) }),
        ]),
      ])
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
  html.button(
    [
      attribute.class("admin-page__button admin-page__button--secondary"),
      attribute.attribute("type", "button"),
      attribute.disabled(!enabled),
      event.on_click(msg),
    ],
    [html.text(label)],
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

fn table_heading(text: String) -> Element(Msg) {
  html.th([attribute.class("admin-job-logs-table__heading")], [html.text(text)])
}

fn log_row(log: job_log_dto.JobLogResponse, now: Timestamp) -> Element(Msg) {
  html.tr([attribute.class("admin-job-logs-table__row")], [
    html.td([attribute.class("admin-job-logs-table__cell")], [
      html.div([attribute.class("jobs-table__stack")], [
        html.a(
          [
            attribute.class("jobs-table__primary admin-job-logs-page__link"),
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
    html.td([attribute.class("admin-job-logs-table__cell")], [
      html.span([attribute.class("jobs-table__primary")], [
        html.text(timestamp_helpers.relative_label(log.created_at, now)),
      ]),
    ]),
    html.td([attribute.class("admin-job-logs-table__cell")], [
      html.div([attribute.class("jobs-table__stack")], [
        html.span([attribute.class("jobs-table__primary")], [
          html.text(log.job_type),
        ]),
      ]),
    ]),
    html.td(
      [
        attribute.class(
          "admin-job-logs-table__cell admin-job-logs-table__cell--attempt",
        ),
      ],
      [html.text(int.to_string(log.attempt))],
    ),
    html.td(
      [
        attribute.class(
          "admin-job-logs-table__cell admin-job-logs-table__cell--duration",
        ),
      ],
      [html.text(duration_label.duration_in_ms_label(log.duration_ns))],
    ),
    html.td(
      [
        attribute.class(
          "admin-job-logs-table__cell admin-job-logs-table__cell--error",
        ),
      ],
      [
        html.span([attribute.class(error_badge_class(log))], [
          html.text(error_text(log)),
        ]),
      ],
    ),
    html.td(
      [
        attribute.class(
          "admin-job-logs-table__cell admin-job-logs-table__cell--actions",
        ),
      ],
      [
        html.a(
          [
            attribute.class("admin-page__button admin-page__button--secondary"),
            route.href(route.AdminJobLog(log.id)),
          ],
          [html.text("Open")],
        ),
      ],
    ),
  ])
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

fn error_badge_class(log: job_log_dto.JobLogResponse) -> String {
  case log.has_error {
    True -> "jobs-table__badge jobs-table__badge--failed"
    False -> "jobs-table__badge jobs-table__badge--done"
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
