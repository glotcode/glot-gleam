import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/run_log_dto
import glot_core/language
import glot_core/run_log_model
import glot_frontend/api
import glot_frontend/duration_label
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import youid/uuid

pub type Model {
  Model(
    id: uuid.Uuid,
    log: option.Option(run_log_dto.RunLogDetailResponse),
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
  LogLoaded(api.ApiResponse(run_log_dto.GetRunLogResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(id: id, log: option.None, status: NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      api.get_admin_run_log(
        run_log_dto.GetRunLogRequest(id: model.id),
        LogLoaded,
      ),
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
          Model(..model, status: LoadError("Could not load run log.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section(
        [attribute.class("app-panel admin-page admin-job-log-page")],
        [
          html.div([attribute.class("admin-page__header")], [
            html.div([], [
              html.h2([attribute.class("admin-page__title")], [
                html.text("Run log detail"),
              ]),
              html.p([attribute.class("admin-page__status")], [
                html.text(
                  "Inspect one retained code execution outcome and its request correlation fields.",
                ),
              ]),
            ]),
          ]),
          status_view(model),
          detail_view(model),
        ],
      ),
    ]),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading run log..."),
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
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading run log..."),
      ])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This run log could not be loaded."),
      ])
    option.Some(log), _ ->
      html.div([attribute.class("admin-job-page__content")], [
        html.div(
          [
            attribute.class(
              "admin-job-page__summary-grid admin-job-log-page__summary-grid",
            ),
          ],
          [
            summary_card("Log ID", uuid.to_string(log.id), "Retained run entry"),
            summary_card(
              "Request ID",
              uuid.to_string(log.request_id),
              "Originating request",
            ),
            summary_card(
              "Language",
              language.name(log.language),
              "Runtime language",
            ),
            summary_card("Outcome", outcome_text(log.outcome), "Execution state"),
            summary_card("Created at", format_timestamp(log.created_at), "UTC"),
            summary_card("Duration", optional_duration(log.duration_ns), "Runtime"),
          ],
        ),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Run log"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Persistent correlation fields are separated from the summary so failed runs can be traced cleanly.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-job-page__detail-grid")], [
            detail_item("Log ID", uuid.to_string(log.id)),
            detail_item("Request ID", uuid.to_string(log.request_id)),
            detail_item("Session ID", optional_uuid(log.session_id)),
            detail_item("User ID", optional_uuid(log.user_id)),
            detail_item("Language", language.name(log.language)),
            detail_item("Outcome", outcome_text(log.outcome)),
            detail_item("Created at", format_timestamp(log.created_at)),
            detail_item("Duration", optional_duration(log.duration_ns)),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Failure message"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Stored only when the execution fails before producing a successful run result.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy")], [
            html.pre([attribute.class("admin-job-page__code-block")], [
              html.text(optional_text(log.failure_message)),
            ]),
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

fn format_timestamp(value) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
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

fn optional_duration(duration_ns: option.Option(Int)) -> String {
  case duration_ns {
    option.Some(value) -> duration_label.duration_in_ms_label(value)
    option.None -> "None"
  }
}

fn outcome_text(outcome: run_log_model.RunOutcome) -> String {
  case outcome {
    run_log_model.RunSucceeded -> "Succeeded"
    run_log_model.RunFailed -> "Failed"
  }
}
