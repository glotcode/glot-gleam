import gleam/int
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/job_dto
import glot_core/helpers/timestamp_helpers
import glot_core/route
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import youid/uuid

pub type Model {
  Model(job_id: uuid.Uuid, job: option.Option(job_dto.JobDetailResponse), status: Status)
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type Msg {
  JobLoaded(api.ApiResponse(job_dto.GetJobResponse))
}

pub fn init(job_id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(job_id: job_id, job: option.None, status: NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded ->
      #(
        Model(..model, status: Loading),
        api.get_admin_job(job_dto.GetJobRequest(id: model.job_id), JobLoaded),
      )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    JobLoaded(result) ->
      case result {
        api.ApiSuccess(response) ->
          #(Model(..model, job: option.Some(response.job), status: Ready), effect.none())
        api.ApiFailure(error) -> #(Model(..model, status: LoadError(error.message)), effect.none())
        api.HttpFailure(_) ->
          #(Model(..model, status: LoadError("Could not load job.")), effect.none())
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
              html.text("Inspect one job execution, its scheduling metadata, and any stored payload or error output."),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            html.a(
              [
                attribute.class("admin-page__button admin-page__button--secondary"),
                route.href(route.AdminJobs),
              ],
              [html.text("Back to jobs")],
            ),
          ]),
        ]),
        status_view(model),
        detail_view(model, now),
      ]),
    ]),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [html.text("Loading job...")])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn detail_view(model: Model, now: Timestamp) -> Element(Msg) {
  case model.job, model.status {
    option.None, Loading ->
      html.div([attribute.class("admin-page__empty")], [html.text("Loading job...")])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This job could not be loaded."),
      ])
    option.Some(job), _ ->
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class("admin-job-page__summary-grid")], [
          summary_card("Status", status_text(job), type_group_text(job.job_type)),
          summary_card(
            "Scheduled",
            timestamp_helpers.relative_label(job.run_at, now),
            "Updated " <> timestamp_helpers.relative_label(job.updated_at, now),
          ),
          summary_card(
            "Attempts",
            int.to_string(job.attempts) <> " / " <> int.to_string(job.max_attempts),
            "Timeout " <> int.to_string(job.timeout_seconds) <> "s",
          ),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [html.text("Metadata")]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text("Identifiers and timestamps captured for this execution."),
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
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [html.text("Notes")]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text("Current operator-facing interpretation of this job state."),
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
            html.h3([attribute.class("admin-page__group-title")], [html.text("Payload")]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text("Stored raw payload string for this job, if any."),
            ]),
          ]),
          code_block(optional_text(job.payload)),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [html.text("Last error")]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text("Latest persisted failure message, if one was recorded."),
            ]),
          ]),
          code_block(optional_text(job.last_error)),
        ]),
      ])
  }
}

fn summary_card(title: String, value: String, meta: String) -> Element(Msg) {
  html.article(
    [attribute.class("admin-page__policy admin-job-page__summary-card")],
    [
      html.span([attribute.class("admin-job-page__eyebrow")], [html.text(title)]),
      html.strong([attribute.class("admin-job-page__summary-value")], [html.text(value)]),
      html.span([attribute.class("admin-job-page__meta")], [html.text(meta)]),
    ],
  )
}

fn detail_item(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-job-page__detail-item")], [
    html.span([attribute.class("admin-job-page__eyebrow")], [html.text(label)]),
    html.span([attribute.class("admin-job-page__detail-value")], [html.text(value)]),
  ])
}

fn code_block(value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy")], [
    html.pre([attribute.class("admin-job-page__code-block")], [html.text(value)]),
  ])
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
