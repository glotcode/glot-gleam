import gleam/option
import glot_core/language
import glot_core/loadable
import glot_core/run_log_model
import glot_frontend/admin/run_logs/detail_message.{type Msg}
import glot_frontend/admin/run_logs/detail_model.{type Model}
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
    title: "Run log detail",
    intro: "Inspect one retained code execution outcome and its request correlation fields.",
    actions: [],
    content: [
      admin_status.loadable_status(model.log, "Loading run log..."),
      detail_view(model),
    ],
  )
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.log,
    admin_status.empty_state("This run log could not be loaded."),
    admin_status.empty_state("Loading run log..."),
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
            admin_layout.summary_card(
              "Request ID",
              uuid.to_string(log.request_id),
            ),
            admin_layout.summary_card("Language", language.name(log.language)),
            admin_layout.summary_card("Outcome", outcome_text(log.outcome)),
            admin_layout.summary_card(
              "Created at",
              admin_format.format_timestamp(log.created_at),
            ),
            admin_layout.summary_card(
              "Duration",
              optional_duration(log.duration_ns),
            ),
          ],
        ),
        admin_layout.section(
          title: "Run log",
          copy: "Persistent correlation fields are separated from the summary so failed runs can be traced cleanly.",
          content: html.div(
            [attribute.class(admin_layout.detail_grid_class())],
            [
              admin_layout.detail_item("Log ID", uuid.to_string(log.id)),
              admin_layout.detail_item(
                "Request ID",
                uuid.to_string(log.request_id),
              ),
              admin_layout.detail_item(
                "Session ID",
                admin_format.optional_uuid(log.session_id),
              ),
              admin_layout.detail_item(
                "User ID",
                admin_format.optional_uuid(log.user_id),
              ),
              admin_layout.detail_item("Language", language.name(log.language)),
              admin_layout.detail_item("Outcome", outcome_text(log.outcome)),
              admin_layout.detail_item(
                "Created at",
                admin_format.format_timestamp(log.created_at),
              ),
              admin_layout.detail_item(
                "Duration",
                optional_duration(log.duration_ns),
              ),
            ],
          ),
        ),
        admin_layout.section(
          title: "Failure message",
          copy: "Stored only when the execution fails before producing a successful run result.",
          content: admin_layout.optional_code_block(log.failure_message),
        ),
      ])
    },
    fn(_) { admin_status.empty_state("This run log could not be loaded.") },
  )
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
