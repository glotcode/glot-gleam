import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/job_log_dto
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/admin_cursor_page
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
    page: loadable.Loadable(
      pagination_model.CursorPage(job_log_dto.JobLogResponse),
    ),
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
    LogsLoaded(result) ->
      case result {
        _ -> #(
          Model(
            ..model,
            page: admin_cursor_page.page_from_response(
              result,
              fn(response) { response.page },
              "Could not load job logs.",
            ),
          ),
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

  admin_ui.page_with_panel_class(
    panel_class: "admin-job-logs-page",
    title: "Job logs",
    intro: "",
    actions: admin_ui.cursor_pagination_actions(
      current_page(model),
      PreviousPageClicked,
      NextPageClicked,
    ),
    content: [
      admin_ui.filter_section(
        copy: filter_summary(model, rows),
        content: admin_ui.filter_surface([], [
          admin_ui.filter_field_grid(
            [attribute.class("admin-job-logs-page__field-grid")],
            [
              admin_ui.text_input(
                label: "Request ID",
                help: request_id_help(model),
                value: model.request_id_filter,
                placeholder: "UUID",
                on_input: RequestIdFilterChanged,
              ),
              admin_ui.text_input(
                label: "Job ID",
                help: job_id_help(model),
                value: model.job_id_filter,
                placeholder: "UUID",
                on_input: JobIdFilterChanged,
              ),
            ],
          ),
          admin_ui.filter_row([], [
            admin_ui.filter_chip_group(
              title: "Error",
              copy: option.None,
              chips: [
                admin_ui.filter_chip(
                  [event.on_click(ErrorFilterSelected(job_log_dto.AllJobLogs))],
                  "All",
                  model.error_filter == job_log_dto.AllJobLogs,
                ),
                admin_ui.filter_chip(
                  [
                    event.on_click(ErrorFilterSelected(
                      job_log_dto.OnlyJobLogsWithErrors,
                    )),
                  ],
                  "Errors only",
                  model.error_filter == job_log_dto.OnlyJobLogsWithErrors,
                ),
              ],
            ),
            admin_ui.filter_actions([], [
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
        ]),
      ),
      html.div([attribute.class("admin-page__group")], [
        html.div([attribute.class("admin-page__group-header")], [
          html.h3([attribute.class("admin-page__group-title")], [
            html.text("Results"),
          ]),
        ]),
        admin_ui.loadable_status(model.page, "Loading job logs..."),
        logs_table(model, now),
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

fn logs_table(model: Model, now: Timestamp) -> Element(Msg) {
  admin_ui.loadable_cursor_page_content(
    model.page,
    "Loading job logs...",
    "No job logs matched these filters.",
    fn(rows) {
      admin_table.table(log_columns(), {
        rows |> list.map(fn(log) { log_row(log, now) })
      })
    },
  )
}

fn current_page(
  model: Model,
) -> pagination_model.CursorPage(job_log_dto.JobLogResponse) {
  admin_cursor_page.current_page(model.page)
}

fn log_row(log: job_log_dto.JobLogResponse, now: Timestamp) -> Element(Msg) {
  admin_table.row([
    admin_table.linked_primary_cell(
      log_id_column(),
      [route.href(route.AdminJobLog(log.id))],
      string_helpers.truncate_stem_middle(uuid.to_string(log.id), 18),
      option.None,
    ),
    admin_table.primary_cell(
      when_column(),
      timestamp_helpers.relative_label(log.created_at, now),
    ),
    admin_table.primary_cell(job_type_column(), log.job_type),
    admin_table.value_cell(attempt_column(), int.to_string(log.attempt)),
    admin_table.value_cell(
      duration_column(),
      duration_label.duration_in_ms_label(log.duration_ns),
    ),
    admin_table.cell(error_column(), [admin_ui.error_badge(log.has_error)]),
    admin_table.open_link_cell([route.href(route.AdminJobLog(log.id))]),
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
  admin_table.open_column()
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
