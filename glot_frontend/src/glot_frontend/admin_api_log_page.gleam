import gleam/int
import gleam/option
import glot_core/admin/api_log_dto
import glot_core/effect_trace_dto
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
  Model(id: uuid.Uuid, log: loadable.Loadable(api_log_dto.ApiLogDetailResponse))
}

pub type Msg {
  LogLoaded(api.ApiResponse(api_log_dto.GetApiLogResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(id: id, log: loadable.NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case
    loadable.ensure_loaded(
      model.log,
      api.get_admin_api_log(
        api_log_dto.GetApiLogRequest(id: model.id),
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
          Model(..model, log: loadable.LoadError("Could not load API log.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  admin_ui.page_with_panel_class(
    panel_class: "admin-request-log-page",
    title: "API log detail",
    intro: "Inspect the API log captured for one request.",
    actions: [],
    content: [
      admin_ui.loadable_status(model.log, "Loading API log..."),
      detail_view(model),
    ],
  )
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.log,
    admin_ui.empty_state("This API log could not be loaded."),
    admin_ui.empty_state("Loading API log..."),
    fn(log) {
      html.div([attribute.class("admin-job-page__content")], [
        html.div(
          [
            attribute.class(
              admin_ui.summary_grid_class()
              <> " admin-request-log-page__summary-grid",
            ),
          ],
          [
            admin_ui.summary_card("Log ID", uuid.to_string(log.id)),
            admin_ui.summary_card("Request ID", uuid.to_string(log.request_id)),
            admin_ui.summary_card(
              "Created at",
              admin_format.format_timestamp(log.created_at),
            ),
            admin_ui.summary_card("Action", log.log.action),
          ],
        ),
        admin_ui.section(
          title: "API log",
          copy: "Request-handling metadata and raw API log payloads.",
          content: api_log_content(log),
        ),
      ])
    },
    fn(_) { admin_ui.empty_state("This API log could not be loaded.") },
  )
}

fn api_log_content(log: api_log_dto.ApiLogDetailResponse) -> Element(Msg) {
  html.div([attribute.class("admin-request-log-page__section")], [
    html.div([attribute.class(admin_ui.detail_grid_class())], [
      admin_ui.detail_item("Log ID", uuid.to_string(log.id)),
      admin_ui.detail_item("Request ID", uuid.to_string(log.request_id)),
      admin_ui.detail_item(
        "Created at",
        admin_format.format_timestamp(log.created_at),
      ),
      admin_ui.detail_item("Action", log.log.action),
      admin_ui.detail_item("Body bytes", int.to_string(log.log.body_bytes)),
      admin_ui.detail_item(
        "Duration",
        duration_label.duration_in_ms_label(log.log.duration_ns),
      ),
      admin_ui.detail_item("IP", admin_format.optional_text(log.log.ip)),
      admin_ui.detail_item(
        "User agent",
        admin_format.optional_text(log.log.user_agent),
      ),
    ]),
    raw_blocks(
      log.log.info,
      log.log.warnings,
      log.log.debug,
      log.log.error,
      log.log.effects,
    ),
  ])
}

fn raw_blocks(
  info: option.Option(String),
  warnings: option.Option(String),
  debug: option.Option(String),
  error: option.Option(String),
  effects: option.Option(effect_trace_dto.EffectTraceResponse),
) -> Element(Msg) {
  html.div([attribute.class("admin-request-log-page__raw-grid")], [
    admin_ui.optional_raw_block("Info", info),
    admin_ui.optional_raw_block("Warnings", warnings),
    admin_ui.optional_raw_block("Debug", debug),
    admin_ui.optional_raw_block("Error", error),
    admin_effects_table.effects_block(effects),
  ])
}
