import gleam/dynamic/decode
import gleam/option
import glot_core/route
import glot_frontend/admin/jobs/constants
import glot_frontend/admin/jobs/message.{
  type Msg, CreateJobCancelled, CreateJobDialogClosed,
  CreateJobMaxAttemptsChanged, CreateJobPayloadChanged, CreateJobRunDateChanged,
  CreateJobRunTimeChanged, CreateJobSubmitted, CreateJobTimeoutSecondsChanged,
}
import glot_frontend/admin/jobs/model.{
  type CreateJobEditor, type CreateJobState, type Model, CreateJobError,
  CreateJobIdle, CreateJobSaved, CreateJobSaving,
}
import glot_frontend/admin/ui/dialog as admin_dialog
import glot_frontend/admin/ui/form as admin_form
import glot_frontend/admin/ui/format as admin_format
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/admin/ui/status as admin_status
import glot_web/route as web_route
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

pub fn view(model: Model) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(constants.create_job_dialog_id),
      attribute.class("app-dialog admin-page__dialog"),
      attribute.attribute("aria-label", "Start new job"),
      event.on("close", decode.success(CreateJobDialogClosed)),
    ],
    [
      case model.create_job_editor {
        option.Some(editor) -> create_job_dialog_form(editor)
        option.None -> html.div([], [])
      },
    ],
  )
}

fn create_job_dialog_form(editor: CreateJobEditor) -> Element(Msg) {
  admin_dialog.dialog_form([event.on_submit(fn(_) { CreateJobSubmitted })], [
    admin_dialog.dialog_section([
      admin_dialog.dialog_header_with_close(
        title: "Start new job",
        copy: "Seeded from the selected job, but this creates a fresh queued job with the values below.",
        close_attributes: [event.on_click(CreateJobCancelled)],
        close_label: "Close",
      ),
      html.div([attribute.class("admin-page__modal-grid")], [
        admin_layout.detail_item(
          "Source job ID",
          uuid.to_string(editor.source_job_id),
        ),
        admin_layout.detail_item("Job type", editor.draft.job_type),
        admin_layout.detail_item(
          "Periodic job ID",
          admin_format.optional_uuid(editor.draft.periodic_job_id),
        ),
      ]),
      html.div([attribute.class("admin-page__modal-grid")], [
        admin_form.text_input_with_attrs(
          label: "Max attempts",
          help: "Whole number greater than zero.",
          value: editor.draft.max_attempts,
          placeholder: "",
          input_type: "text",
          field_class: "",
          input_class: "",
          input_attributes: [],
          on_input: CreateJobMaxAttemptsChanged,
        ),
        admin_form.text_input_with_attrs(
          label: "Timeout seconds",
          help: "Whole number greater than zero.",
          value: editor.draft.timeout_seconds,
          placeholder: "",
          input_type: "text",
          field_class: "",
          input_class: "",
          input_attributes: [],
          on_input: CreateJobTimeoutSecondsChanged,
        ),
        admin_form.text_input_with_attrs(
          label: "Run date",
          help: "Local calendar date for when the job should be eligible.",
          value: editor.draft.run_date,
          placeholder: "",
          input_type: "date",
          field_class: "",
          input_class: "",
          input_attributes: [],
          on_input: CreateJobRunDateChanged,
        ),
        admin_form.text_input_with_attrs(
          label: "Run time",
          help: "Local clock time for when the job should be eligible.",
          value: editor.draft.run_time,
          placeholder: "",
          input_type: "time",
          field_class: "",
          input_class: "",
          input_attributes: [],
          on_input: CreateJobRunTimeChanged,
        ),
      ]),
      admin_form.textarea_input_with_attrs(
        label: "Payload",
        help: "Raw payload string. Leave empty to create the job without a payload.",
        value: editor.draft.payload,
        rows: 6,
        field_class: "admin-periodic-jobs-page__payload-field",
        textarea_class: "admin-periodic-jobs-page__payload-input",
        textarea_attributes: [],
        on_input: CreateJobPayloadChanged,
      ),
      admin_layout.form_status_block(create_job_status(editor.state)),
    ]),
    admin_dialog.dialog_actions([
      admin_dialog.dialog_cancel_button(
        [
          attribute.type_("button"),
          event.on_click(CreateJobCancelled),
        ],
        "Cancel",
      ),
      admin_dialog.dialog_primary_button(
        [
          attribute.type_("submit"),
          attribute.disabled(editor.state == CreateJobSaving),
        ],
        create_job_submit_text(editor.state),
      ),
    ]),
  ])
}

fn create_job_status(state: CreateJobState) -> Element(Msg) {
  case state {
    CreateJobIdle -> admin_status.status("")
    CreateJobSaving -> admin_status.status("Creating job...")
    CreateJobError(message) -> admin_status.error_status(message)
    CreateJobSaved(job) ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Created new job successfully. "),
        html.a([web_route.href(route.Admin(route.AdminJob(job.id)))], [
          html.text("Open new job"),
        ]),
        html.text("."),
      ])
  }
}

fn create_job_submit_text(state: CreateJobState) -> String {
  case state {
    CreateJobSaving -> "Starting..."
    CreateJobIdle | CreateJobError(_) | CreateJobSaved(_) -> "Start job"
  }
}
