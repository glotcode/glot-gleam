import gleam/int
import gleam/list
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/job_dto
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

const job_logs_page_limit = 25

pub type Model {
  Model(
    job_id: uuid.Uuid,
    job: option.Option(job_dto.JobDetailResponse),
    job_status: Status,
    logs_page: pagination_model.CursorPage(job_log_dto.JobLogResponse),
    logs_status: Status,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type Msg {
  JobLoaded(api.ApiResponse(job_dto.GetJobResponse))
  JobLogsLoaded(api.ApiResponse(job_log_dto.ListJobLogsResponse))
  NextLogsPageClicked
  PreviousLogsPageClicked
}

pub fn init(job_id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(
    Model(
      job_id: job_id,
      job: option.None,
      job_status: NotLoaded,
      logs_page: empty_logs_page(),
      logs_status: NotLoaded,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  let should_load_job = model.job_status == NotLoaded
  let should_load_logs = model.logs_status == NotLoaded

  case should_load_job || should_load_logs {
    False -> #(model, effect.none())
    True -> #(
      Model(
        ..model,
        job_status: loading_status(model.job_status),
        logs_status: loading_status(model.logs_status),
      ),
      effect.batch([
        case should_load_job {
          True ->
            api.get_admin_job(
              job_dto.GetJobRequest(id: model.job_id),
              JobLoaded,
            )
          False -> effect.none()
        },
        case should_load_logs {
          True ->
            get_job_logs(
              model,
              pagination_model.InitialPage(limit: job_logs_page_limit),
            )
          False -> effect.none()
        },
      ]),
    )
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    JobLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, job: option.Some(response.job), job_status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, job_status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, job_status: LoadError("Could not load job.")),
          effect.none(),
        )
      }

    JobLogsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, logs_page: response.page, logs_status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, logs_status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, logs_status: LoadError("Could not load job logs.")),
          effect.none(),
        )
      }

    NextLogsPageClicked ->
      case pagination_model.next_cursor(model.logs_page) {
        option.Some(cursor) ->
          load_job_logs_page(
            model,
            pagination_model.AfterPage(
              cursor: cursor,
              limit: job_logs_page_limit,
            ),
          )
        option.None -> #(model, effect.none())
      }

    PreviousLogsPageClicked ->
      case pagination_model.previous_cursor(model.logs_page) {
        option.Some(cursor) ->
          load_job_logs_page(
            model,
            pagination_model.BeforePage(
              cursor: cursor,
              limit: job_logs_page_limit,
            ),
          )
        option.None -> #(model, effect.none())
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-job-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Job detail"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "Inspect one job execution, its scheduling metadata, and any stored payload or error output.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            html.a(
              [
                attribute.class(
                  "admin-page__button admin-page__button--secondary",
                ),
                route.href(route.AdminJobs),
              ],
              [html.text("Back to jobs")],
            ),
          ]),
        ]),
        job_status_view(model),
        detail_view(model, now),
      ]),
    ]),
  ])
}

fn job_status_view(model: Model) -> Element(Msg) {
  case model.job_status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading job..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn detail_view(model: Model, now: Timestamp) -> Element(Msg) {
  case model.job, model.job_status {
    option.None, Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading job..."),
      ])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This job could not be loaded."),
      ])
    option.Some(job), _ ->
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class("admin-job-page__summary-grid")], [
          summary_card(
            "Status",
            status_text(job),
            type_group_text(job.job_type),
          ),
          summary_card(
            "Scheduled",
            timestamp_helpers.relative_label(job.run_at, now),
            "Updated " <> timestamp_helpers.relative_label(job.updated_at, now),
          ),
          summary_card(
            "Attempts",
            int.to_string(job.attempts)
              <> " / "
              <> int.to_string(job.max_attempts),
            "Timeout " <> int.to_string(job.timeout_seconds) <> "s",
          ),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Metadata"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Identifiers and timestamps captured for this execution.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-job-page__detail-grid")], [
            detail_item("Job ID", uuid.to_string(job.id)),
            detail_item("Request ID", optional_uuid(job.request_id)),
            detail_item("Periodic job ID", optional_uuid(job.periodic_job_id)),
            detail_item("Type", job.job_type),
            detail_item("Status", status_text(job)),
            detail_item("Overdue", bool_text(job.overdue)),
            detail_item("Run at", format_timestamp(job.run_at)),
            detail_item("Started at", optional_timestamp(job.started_at)),
            detail_item("Completed at", optional_timestamp(job.completed_at)),
            detail_item("Created at", format_timestamp(job.created_at)),
            detail_item("Updated at", format_timestamp(job.updated_at)),
          ]),
        ]),
        job_logs_group(model, now),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Notes"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Current operator-facing interpretation of this job state.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy")], [
            html.p([attribute.class("admin-job-page__body-text")], [
              html.text(note_text(job)),
            ]),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Payload"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text("Stored raw payload string for this job, if any."),
            ]),
          ]),
          code_block(optional_text(job.payload)),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Last error"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Latest persisted failure message, if one was recorded.",
              ),
            ]),
          ]),
          code_block(optional_text(job.last_error)),
        ]),
      ])
  }
}

fn job_logs_group(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.logs_page)
  let count_text =
    int.to_string(list.length(rows)) <> " log entries shown for this job."

  html.div([attribute.class("admin-page__group")], [
    html.div([attribute.class("admin-page__group-header")], [
      html.div([], [
        html.h3([attribute.class("admin-page__group-title")], [
          html.text("Logs"),
        ]),
        html.p([attribute.class("admin-page__group-copy")], [
          html.text(count_text),
        ]),
      ]),
      html.div([attribute.class("admin-page__policy-actions")], [
        pagination_button(
          "Previous",
          PreviousLogsPageClicked,
          can_go_previous_logs(model),
        ),
        pagination_button("Next", NextLogsPageClicked, can_go_next_logs(model)),
      ]),
    ]),
    logs_status_view(model),
    job_logs_table(model, now),
  ])
}

fn logs_status_view(model: Model) -> Element(Msg) {
  case model.logs_status {
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

fn job_logs_table(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.logs_page)

  case rows, model.logs_status {
    [], Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading job logs..."),
      ])

    [], _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No job logs were found for this job."),
      ])

    _, _ ->
      html.div([attribute.class("jobs-table admin-job-logs-page__table")], [
        html.div(
          [attribute.class("jobs-table__head admin-job-logs-page__head")],
          [
            table_heading("Log ID"),
            table_heading("When"),
            table_heading("Attempt"),
            table_heading("Duration"),
            table_heading("Error"),
            table_heading("Open"),
          ],
        ),
        html.div([attribute.class("jobs-table__body")], {
          rows |> list.map(fn(log) { job_log_row(log, now) })
        }),
      ])
  }
}

fn job_log_row(log: job_log_dto.JobLogResponse, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("jobs-table__row admin-job-logs-page__row")], [
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("Log ID"),
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
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("When"),
      html.span([attribute.class("jobs-table__primary")], [
        html.text(timestamp_helpers.relative_label(log.created_at, now)),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("Attempt"),
      html.span([attribute.class("jobs-table__cell-value")], [
        html.text(int.to_string(log.attempt)),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("Duration"),
      html.span([attribute.class("jobs-table__cell-value")], [
        html.text(duration_label.duration_in_ms_label(log.duration_ns)),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("Error"),
      html.span([attribute.class(error_badge_class(log))], [
        html.text(error_text(log)),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell jobs-table__cell--actions")], [
      cell_label("Open"),
      html.a(
        [
          attribute.class("admin-page__button admin-page__button--secondary"),
          route.href(route.AdminJobLog(log.id)),
        ],
        [html.text("Open")],
      ),
    ]),
  ])
}

fn load_job_logs_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, logs_status: Loading), get_job_logs(model, pagination))
}

fn get_job_logs(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> Effect(Msg) {
  api.get_admin_job_logs(
    job_log_dto.ListJobLogsRequest(
      pagination: pagination,
      request_id: option.None,
      job_id: option.Some(model.job_id),
      error_filter: job_log_dto.AllJobLogs,
    ),
    JobLogsLoaded,
  )
}

fn summary_card(title: String, value: String, meta: String) -> Element(Msg) {
  html.article(
    [attribute.class("admin-page__policy admin-job-page__summary-card")],
    [
      html.span([attribute.class("admin-job-page__eyebrow")], [html.text(title)]),
      html.strong([attribute.class("admin-job-page__summary-value")], [
        html.text(value),
      ]),
      html.span([attribute.class("admin-job-page__meta")], [html.text(meta)]),
    ],
  )
}

fn detail_item(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-job-page__detail-item")], [
    html.span([attribute.class("admin-job-page__eyebrow")], [html.text(label)]),
    html.span([attribute.class("admin-job-page__detail-value")], [
      html.text(value),
    ]),
  ])
}

fn code_block(value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy")], [
    html.pre([attribute.class("admin-job-page__code-block")], [html.text(value)]),
  ])
}

fn empty_logs_page() -> pagination_model.CursorPage(job_log_dto.JobLogResponse) {
  pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
}

fn loading_status(status: Status) -> Status {
  case status {
    NotLoaded -> Loading
    Loading | Ready | LoadError(_) -> status
  }
}

fn can_go_previous_logs(model: Model) -> Bool {
  case pagination_model.previous_cursor(model.logs_page) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn can_go_next_logs(model: Model) -> Bool {
  case pagination_model.next_cursor(model.logs_page) {
    option.Some(_) -> True
    option.None -> False
  }
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

fn table_heading(text: String) -> Element(Msg) {
  html.span([attribute.class("jobs-table__heading")], [html.text(text)])
}

fn cell_label(text: String) -> Element(Msg) {
  html.span([attribute.class("jobs-table__cell-label")], [html.text(text)])
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

fn optional_uuid(value: option.Option(uuid.Uuid)) -> String {
  case value {
    option.Some(id) -> uuid.to_string(id)
    option.None -> "None"
  }
}

fn optional_timestamp(value: option.Option(Timestamp)) -> String {
  case value {
    option.Some(timestamp) -> format_timestamp(timestamp)
    option.None -> "None"
  }
}

fn format_timestamp(value: Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}

fn optional_text(value: option.Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> "None"
  }
}

fn bool_text(value: Bool) -> String {
  case value {
    True -> "Yes"
    False -> "No"
  }
}

fn status_text(job: job_dto.JobDetailResponse) -> String {
  case job.status, job.overdue {
    "pending", True -> "Pending • overdue"
    "pending", False -> "Pending"
    "running", _ -> "Running"
    "failed", _ -> "Failed"
    "done", _ -> "Done"
    value, _ -> value
  }
}

fn type_group_text(job_type: String) -> String {
  case job_type {
    "send_email" | "delete_account" -> "User lifecycle"
    "aggregate_metrics" -> "Infrastructure"
    _ -> "Cleanup"
  }
}

fn note_text(job: job_dto.JobDetailResponse) -> String {
  case job.last_error {
    option.Some(last_error) -> last_error
    option.None ->
      case job.status {
        "pending" ->
          case job.overdue {
            True -> "Queued past its scheduled run time."
            False -> "Queued and waiting for the worker."
          }
        "running" -> "Currently being processed."
        "failed" -> "Failed without a stored error message."
        "done" -> "Completed successfully."
        _ -> ""
      }
  }
}
