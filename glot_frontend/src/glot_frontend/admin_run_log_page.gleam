import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/run_log_dto
import glot_core/language
import glot_core/run_log_model
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/duration_label
import glot_frontend/loadable
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import youid/uuid

pub type Model {
  Model(id: uuid.Uuid, log: loadable.Loadable(run_log_dto.RunLogDetailResponse))
}

pub type Msg {
  LogLoaded(api.ApiResponse(run_log_dto.GetRunLogResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(id: id, log: loadable.NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case loadable.ensure_loaded(
    model.log,
    api.get_admin_run_log(
      run_log_dto.GetRunLogRequest(id: model.id),
      LogLoaded,
    ),
  ) {
    #(next_log, next_effect) -> #(
      Model(..model, log: next_log),
      next_effect,
    )
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LogLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, log: loadable.Loaded(response.log)),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, log: loadable.LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, log: loadable.LoadError("Could not load run log.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  admin_ui.page_with_panel_class(
    panel_class: "admin-job-log-page",
    title: "Run log detail",
    intro:
      "Inspect one retained code execution outcome and its request correlation fields.",
    actions: [],
    content: [status_view(model), detail_view(model)],
  )
}

fn status_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.log,
    admin_ui.status(""),
    admin_ui.status("Loading run log..."),
    fn(_) { admin_ui.status("") },
    admin_ui.error_status,
  )
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.log,
    admin_ui.empty_state("This run log could not be loaded."),
    admin_ui.empty_state("Loading run log..."),
    fn(log) {
      html.div([attribute.class("admin-job-page__content")], [
        html.div(
          [
            attribute.class(
              admin_ui.summary_grid_class()
              <> " admin-job-log-page__summary-grid",
            ),
          ],
          [
            admin_ui.summary_card("Log ID", uuid.to_string(log.id)),
            admin_ui.summary_card("Request ID", uuid.to_string(log.request_id)),
            admin_ui.summary_card("Language", language.name(log.language)),
            admin_ui.summary_card("Outcome", outcome_text(log.outcome)),
            admin_ui.summary_card(
              "Created at",
              format_timestamp(log.created_at),
            ),
            admin_ui.summary_card(
              "Duration",
              optional_duration(log.duration_ns),
            ),
          ],
        ),
        admin_ui.section(
          title: "Run log",
          copy: "Persistent correlation fields are separated from the summary so failed runs can be traced cleanly.",
          content: html.div([attribute.class(admin_ui.detail_grid_class())], [
            admin_ui.detail_item("Log ID", uuid.to_string(log.id)),
            admin_ui.detail_item("Request ID", uuid.to_string(log.request_id)),
            admin_ui.detail_item("Session ID", optional_uuid(log.session_id)),
            admin_ui.detail_item("User ID", optional_uuid(log.user_id)),
            admin_ui.detail_item("Language", language.name(log.language)),
            admin_ui.detail_item("Outcome", outcome_text(log.outcome)),
            admin_ui.detail_item("Created at", format_timestamp(log.created_at)),
            admin_ui.detail_item("Duration", optional_duration(log.duration_ns)),
          ]),
        ),
        admin_ui.section(
          title: "Failure message",
          copy: "Stored only when the execution fails before producing a successful run result.",
          content: html.div([attribute.class("admin-page__policy")], [
            html.pre([attribute.class("admin-job-page__code-block")], [
              html.text(optional_text(log.failure_message)),
            ]),
          ]),
        ),
      ])
    },
    fn(_) { admin_ui.empty_state("This run log could not be loaded.") },
  )
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
