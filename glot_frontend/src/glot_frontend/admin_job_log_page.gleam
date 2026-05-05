import gleam/float
import gleam/int
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/job_log_dto
import glot_core/route
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import youid/uuid

pub type Model {
  Model(id: uuid.Uuid, log: option.Option(job_log_dto.JobLogDetailResponse), status: Status)
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type Msg {
  LogLoaded(api.ApiResponse(job_log_dto.GetJobLogResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(id: id, log: option.None, status: NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded ->
      #(
        Model(..model, status: Loading),
        api.get_admin_job_log(job_log_dto.GetJobLogRequest(id: model.id), LogLoaded),
      )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LogLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, log: option.Some(response.log), status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load job log.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-job-log-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Job log detail"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text("Inspect one retained job log execution and its raw operator-facing payloads."),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            html.a(
              [
                attribute.class("admin-page__button admin-page__button--secondary"),
                route.href(route.AdminJobLogs),
              ],
              [html.text("Back to job logs")],
            ),
          ]),
        ]),
        status_view(model),
        detail_view(model),
      ]),
    ]),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading job log..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.log, model.status {
    option.None, Loading ->
      html.div([attribute.class("admin-page__empty")], [html.text("Loading job log...")])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This job log could not be loaded."),
      ])
    option.Some(log), _ ->
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class("admin-job-page__summary-grid admin-job-log-page__summary-grid")], [
          summary_card("Log ID", uuid.to_string(log.id), "Retained job log entry"),
          summary_card("Job ID", uuid.to_string(log.job_id), "Originating job"),
          summary_card("Request ID", optional_uuid(log.request_id), "Linked request"),
          summary_card("Job type", log.job_type, "Execution kind"),
          summary_card("Attempt", int.to_string(log.attempt), "Attempt number"),
          summary_card("Created at", format_timestamp(log.created_at), "UTC"),
          summary_card("Duration", duration_in_ms_label(log.duration_ns), "Persisted runtime"),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [html.text("Raw output")]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text("Stored raw blocks are expanded by default so retries and failures can be inspected immediately."),
            ]),
          ]),
          html.div([attribute.class("admin-job-log-page__raw-grid")], [
            raw_block("Info", log.info),
            raw_block("Warnings", log.warnings),
            raw_block("Debug", log.debug),
            raw_block("Error", log.error),
            raw_block("Effects", log.effects),
          ]),
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

fn raw_block(title: String, value: option.Option(String)) -> Element(Msg) {
  html.div([attribute.class("admin-page__group")], [
    html.h4([attribute.class("admin-page__group-title")], [html.text(title)]),
    html.div([attribute.class("admin-page__policy")], [
      html.pre([attribute.class("admin-job-page__code-block")], [
        html.text(optional_text(value)),
      ]),
    ]),
  ])
}

fn format_timestamp(value) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}

fn duration_in_ms_label(duration_ns: Int) -> String {
  let hundredths_of_ms =
    int.to_float(duration_ns) /. 10_000.0
    |> float.round

  let whole_ms = hundredths_of_ms / 100
  let fractional_ms =
    hundredths_of_ms % 100
    |> int.to_string
    |> string.pad_start(to: 2, with: "0")

  int.to_string(whole_ms) <> "." <> fractional_ms <> "ms"
}

fn optional_uuid(value: option.Option(uuid.Uuid)) -> String {
  case value {
    option.Some(id) -> uuid.to_string(id)
    option.None -> "None"
  }
}

fn optional_text(value: option.Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> "None"
  }
}
