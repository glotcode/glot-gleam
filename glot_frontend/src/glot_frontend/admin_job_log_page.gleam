import gleam/int
import glot_core/admin/job_log_dto
import glot_frontend/admin_effects_table
import glot_frontend/admin_format
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
  Model(id: uuid.Uuid, log: loadable.Loadable(job_log_dto.JobLogDetailResponse))
}

pub type Msg {
  LogLoaded(api.ApiResponse(job_log_dto.GetJobLogResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(id: id, log: loadable.NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case
    loadable.ensure_loaded(
      model.log,
      api.get_admin_job_log(
        job_log_dto.GetJobLogRequest(id: model.id),
        LogLoaded,
      ),
    )
  {
    #(next_log, next_effect) -> #(Model(..model, log: next_log), next_effect)
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
          Model(..model, log: loadable.LoadError("Could not load job log.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  admin_ui.page_with_panel_class(
    panel_class: "admin-job-log-page",
    title: "Job log detail",
    intro: "Inspect one retained job log execution and its raw operator-facing payloads.",
    actions: [],
    content: [
      admin_ui.loadable_status(model.log, "Loading job log..."),
      detail_view(model),
    ],
  )
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.log,
    admin_ui.empty_state("This job log could not be loaded."),
    admin_ui.empty_state("Loading job log..."),
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
            admin_ui.summary_card("Job ID", uuid.to_string(log.job_id)),
            admin_ui.summary_card(
              "Request ID",
              admin_format.optional_uuid(log.request_id),
            ),
            admin_ui.summary_card("Job type", log.job_type),
            admin_ui.summary_card("Attempt", int.to_string(log.attempt)),
            admin_ui.summary_card(
              "Created at",
              admin_format.format_timestamp(log.created_at),
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
            admin_ui.optional_raw_block("Info", log.info),
            admin_ui.optional_raw_block("Warnings", log.warnings),
            admin_ui.optional_raw_block("Debug", log.debug),
            admin_ui.optional_raw_block("Error", log.error),
            admin_effects_table.effects_block(log.effects),
          ]),
        ),
      ])
    },
    fn(_) { admin_ui.empty_state("This job log could not be loaded.") },
  )
}
