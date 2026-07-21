import gleam/int
import glot_core/loadable
import glot_frontend/admin/job_logs/detail_message.{type Msg}
import glot_frontend/admin/job_logs/detail_model.{type Model}
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
    panel_class: "admin-job-log-page",
    title: "Job log detail",
    intro: "Inspect one retained job log execution and its raw operator-facing payloads.",
    actions: [],
    content: [
      admin_status.loadable_status(model.log, "Loading job log..."),
      detail_view(model),
    ],
  )
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.log,
    admin_status.empty_state("This job log could not be loaded."),
    admin_status.empty_state("Loading job log..."),
    fn(log) {
      html.div([attribute.class("admin-job-page__content")], [
        html.div(
          [
            attribute.class(
              admin_layout.summary_grid_class()
              <> " admin-job-log-page__summary-grid",
            ),
          ],
          [
            admin_layout.summary_card("Log ID", uuid.to_string(log.id)),
            admin_layout.summary_card("Job ID", uuid.to_string(log.job_id)),
            admin_layout.summary_card(
              "Request ID",
              admin_format.optional_uuid(log.request_id),
            ),
            admin_layout.summary_card("Job type", log.job_type),
            admin_layout.summary_card("Attempt", int.to_string(log.attempt)),
            admin_layout.summary_card(
              "Created at",
              admin_format.format_timestamp(log.created_at),
            ),
            admin_layout.summary_card(
              "Duration",
              duration_label.duration_in_ms_label(log.duration_ns),
            ),
          ],
        ),
        admin_layout.section(
          title: "Raw output",
          copy: "Stored raw blocks are expanded by default so retries and failures can be inspected immediately.",
          content: html.div([attribute.class("admin-job-log-page__raw-grid")], [
            json_block.optional_raw_block("Info", log.info),
            json_block.optional_raw_block("Warnings", log.warnings),
            json_block.optional_raw_block("Debug", log.debug),
            json_block.optional_raw_block("Error", log.error),
            admin_effects_table.effects_block(log.effects),
          ]),
        ),
      ])
    },
    fn(_) { admin_status.empty_state("This job log could not be loaded.") },
  )
}
