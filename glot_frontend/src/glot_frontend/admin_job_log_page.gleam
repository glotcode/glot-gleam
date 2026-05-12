import gleam/int
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/job_log_dto
import glot_frontend/admin_effects_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/duration_label
import glot_frontend/json_helpers
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import youid/uuid

pub type Model {
  Model(
    id: uuid.Uuid,
    log: option.Option(job_log_dto.JobLogDetailResponse),
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
  LogLoaded(api.ApiResponse(job_log_dto.GetJobLogResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(id: id, log: option.None, status: NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      api.get_admin_job_log(
        job_log_dto.GetJobLogRequest(id: model.id),
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
          Model(..model, status: LoadError("Could not load job log.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  admin_ui.page_with_panel_class(
    panel_class: "admin-job-log-page",
    title: "Job log detail",
    intro:
      "Inspect one retained job log execution and its raw operator-facing payloads.",
    actions: [],
    content: [status_view(model), detail_view(model)],
  )
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready -> admin_ui.status("")
    Loading -> admin_ui.status("Loading job log...")
    LoadError(message) -> admin_ui.error_status(message)
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.log, model.status {
    option.None, Loading -> admin_ui.empty_state("Loading job log...")
    option.None, _ -> admin_ui.empty_state("This job log could not be loaded.")
    option.Some(log), _ ->
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
            admin_ui.summary_card("Job ID", uuid.to_string(log.job_id)),
            admin_ui.summary_card("Request ID", optional_uuid(log.request_id)),
            admin_ui.summary_card("Job type", log.job_type),
            admin_ui.summary_card("Attempt", int.to_string(log.attempt)),
            admin_ui.summary_card(
              "Created at",
              format_timestamp(log.created_at),
            ),
            admin_ui.summary_card(
              "Duration",
              duration_label.duration_in_ms_label(log.duration_ns),
            ),
          ],
        ),
        admin_ui.section(
          title: "Raw output",
          copy: "Stored raw blocks are expanded by default so retries and failures can be inspected immediately.",
          content: html.div([attribute.class("admin-job-log-page__raw-grid")], [
            raw_block("Info", log.info),
            raw_block("Warnings", log.warnings),
            raw_block("Debug", log.debug),
            raw_block("Error", log.error),
            admin_effects_table.effects_block(log.effects),
          ]),
        ),
      ])
  }
}

fn raw_block(title: String, value: option.Option(String)) -> Element(Msg) {
  html.div([attribute.class("admin-page__group")], [
    html.h4([attribute.class("admin-page__group-title")], [html.text(title)]),
    html.div([attribute.class("admin-page__policy")], [
      html.pre([attribute.class("admin-job-page__code-block")], [
        html.text(json_helpers.optional_pretty_print_json_or_none(value)),
      ]),
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
