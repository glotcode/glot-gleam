import gleam/int
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/api_log_dto
import glot_core/effect_trace_dto
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
    log: option.Option(api_log_dto.ApiLogDetailResponse),
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
  LogLoaded(api.ApiResponse(api_log_dto.GetApiLogResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(id: id, log: option.None, status: NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      api.get_admin_api_log(
        api_log_dto.GetApiLogRequest(id: model.id),
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
          Model(..model, status: LoadError("Could not load API log.")),
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
        [attribute.class("app-panel admin-page admin-request-log-page")],
        [
          html.div([attribute.class("admin-page__header")], [
            html.div([], [
              html.h2([attribute.class("admin-page__title")], [
                html.text("API log detail"),
              ]),
              html.p([attribute.class("admin-page__status")], [
                html.text("Inspect the API log captured for one request."),
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
    NotLoaded | Ready -> admin_ui.status("")
    Loading -> admin_ui.status("Loading API log...")
    LoadError(message) -> admin_ui.error_status(message)
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.log, model.status {
    option.None, Loading -> admin_ui.empty_state("Loading API log...")
    option.None, _ -> admin_ui.empty_state("This API log could not be loaded.")
    option.Some(log), _ ->
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
              format_timestamp(log.created_at),
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
  }
}

fn api_log_content(log: api_log_dto.ApiLogDetailResponse) -> Element(Msg) {
  html.div([attribute.class("admin-request-log-page__section")], [
    html.div([attribute.class(admin_ui.detail_grid_class())], [
      admin_ui.detail_item("Log ID", uuid.to_string(log.id)),
      admin_ui.detail_item("Request ID", uuid.to_string(log.request_id)),
      admin_ui.detail_item("Created at", format_timestamp(log.created_at)),
      admin_ui.detail_item("Action", log.log.action),
      admin_ui.detail_item("Body bytes", int.to_string(log.log.body_bytes)),
      admin_ui.detail_item(
        "Duration",
        duration_label.duration_in_ms_label(log.log.duration_ns),
      ),
      admin_ui.detail_item("IP", optional_text(log.log.ip)),
      admin_ui.detail_item("User agent", optional_text(log.log.user_agent)),
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
    raw_block("Info", info),
    raw_block("Warnings", warnings),
    raw_block("Debug", debug),
    raw_block("Error", error),
    admin_effects_table.effects_block(effects),
  ])
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

fn optional_text(value: option.Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> "None"
  }
}
