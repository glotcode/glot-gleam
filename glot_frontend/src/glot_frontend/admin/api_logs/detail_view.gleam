import gleam/int
import gleam/option
import glot_core/admin/api_log_dto
import glot_core/effect_trace_dto
import glot_core/loadable
import glot_frontend/admin/api_logs/detail_message.{type Msg}
import glot_frontend/admin/api_logs/detail_model.{type Model}
import glot_frontend/admin/presentation/json_block
import glot_frontend/admin/ui/effects_table as admin_effects_table
import glot_frontend/admin/ui/format as admin_format
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/admin/ui/status as admin_status
import glot_frontend/ui/duration_label
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import youid/uuid

pub fn view(model: Model) -> Element(Msg) {
  admin_layout.page_with_panel_class(
    panel_class: "admin-request-log-page",
    title: "API log detail",
    intro: "Inspect the API log captured for one request.",
    actions: [],
    content: [
      admin_status.loadable_status(model.log, "Loading API log..."),
      detail_view(model),
    ],
  )
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.log,
    admin_status.empty_state("This API log could not be loaded."),
    admin_status.empty_state("Loading API log..."),
    fn(log) {
      html.div([attribute.class("admin-job-page__content")], [
        html.div(
          [
            attribute.class(
              admin_layout.summary_grid_class()
              <> " admin-request-log-page__summary-grid",
            ),
          ],
          [
            admin_layout.summary_card("Log ID", uuid.to_string(log.id)),
            admin_layout.summary_card(
              "Request ID",
              uuid.to_string(log.request_id),
            ),
            admin_layout.summary_card(
              "Created at",
              admin_format.format_timestamp(log.created_at),
            ),
            admin_layout.summary_card("Action", log.log.action),
          ],
        ),
        admin_layout.section(
          title: "API log",
          copy: "Request-handling metadata and raw API log payloads.",
          content: api_log_content(log),
        ),
      ])
    },
    fn(_) { admin_status.empty_state("This API log could not be loaded.") },
  )
}

fn api_log_content(log: api_log_dto.ApiLogDetailResponse) -> Element(Msg) {
  html.div([attribute.class("admin-request-log-page__section")], [
    html.div([attribute.class(admin_layout.detail_grid_class())], [
      admin_layout.detail_item("Log ID", uuid.to_string(log.id)),
      admin_layout.detail_item("Request ID", uuid.to_string(log.request_id)),
      admin_layout.detail_item(
        "Created at",
        admin_format.format_timestamp(log.created_at),
      ),
      admin_layout.detail_item("Action", log.log.action),
      admin_layout.detail_item("Body bytes", int.to_string(log.log.body_bytes)),
      admin_layout.detail_item(
        "Duration",
        duration_label.duration_in_ms_label(log.log.duration_ns),
      ),
      admin_layout.detail_item("IP", admin_format.optional_text(log.log.ip)),
      admin_layout.detail_item(
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
    json_block.optional_raw_block("Info", info),
    json_block.optional_raw_block("Warnings", warnings),
    json_block.optional_raw_block("Debug", debug),
    json_block.optional_raw_block("Error", error),
    admin_effects_table.effects_block(effects),
  ])
}
