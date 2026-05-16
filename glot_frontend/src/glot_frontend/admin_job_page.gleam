import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/job_dto
import glot_core/admin/job_log_dto
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/admin_format
import glot_frontend/admin_job_ui
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/app_dialog
import glot_frontend/clock
import glot_frontend/duration_label
import glot_frontend/local_datetime
import glot_frontend/string_helpers
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import youid/uuid

const job_logs_page_limit = 25

const create_job_dialog_id = "admin-job-page-create-job-dialog"

pub type Model {
  Model(
    job_id: uuid.Uuid,
    job: option.Option(job_dto.JobDetailResponse),
    job_status: Status,
    logs_page: pagination_model.CursorPage(job_log_dto.JobLogResponse),
    logs_status: Status,
    create_job_editor: option.Option(CreateJobEditor),
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type CreateJobEditor {
  CreateJobEditor(
    source_job_id: uuid.Uuid,
    draft: CreateJobDraft,
    state: CreateJobState,
  )
}

pub type CreateJobDraft {
  CreateJobDraft(
    periodic_job_id: option.Option(uuid.Uuid),
    job_type: String,
    payload: String,
    max_attempts: String,
    timeout_seconds: String,
    run_date: String,
    run_time: String,
  )
}

pub type CreateJobState {
  CreateJobIdle
  CreateJobSaving
  CreateJobError(String)
  CreateJobSaved(job_dto.JobDetailResponse)
}

pub type Msg {
  JobLoaded(api.ApiResponse(job_dto.GetJobResponse))
  JobLogsLoaded(api.ApiResponse(job_log_dto.ListJobLogsResponse))
  NextLogsPageClicked
  PreviousLogsPageClicked
  OpenCreateJobClicked
  CreateJobDialogClosed
  CreateJobCancelled
  CreateJobSubmitted
  CreateJobFinished(api.ApiResponse(job_dto.GetJobResponse))
  CreateJobPayloadChanged(String)
  CreateJobMaxAttemptsChanged(String)
  CreateJobTimeoutSecondsChanged(String)
  CreateJobRunDateChanged(String)
  CreateJobRunTimeChanged(String)
}

pub fn init(job_id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(
    Model(
      job_id: job_id,
      job: option.None,
      job_status: NotLoaded,
      logs_page: empty_logs_page(),
      logs_status: NotLoaded,
      create_job_editor: option.None,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  let should_load_job = model.job_status == NotLoaded
  let should_load_logs = model.logs_status == NotLoaded

  case should_load_job || should_load_logs {
    False -> #(model, effect.none())
    True -> #(
      Model(
        ..model,
        job_status: loading_status(model.job_status),
        logs_status: loading_status(model.logs_status),
      ),
      effect.batch([
        case should_load_job {
          True ->
            api.get_admin_job(
              job_dto.GetJobRequest(id: model.job_id),
              JobLoaded,
            )
          False -> effect.none()
        },
        case should_load_logs {
          True ->
            get_job_logs(
              model,
              pagination_model.InitialPage(limit: job_logs_page_limit),
            )
          False -> effect.none()
        },
      ]),
    )
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    JobLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, job: option.Some(response.job), job_status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, job_status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, job_status: LoadError("Could not load job.")),
          effect.none(),
        )
      }

    JobLogsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, logs_page: response.page, logs_status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, logs_status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, logs_status: LoadError("Could not load job logs.")),
          effect.none(),
        )
      }

    NextLogsPageClicked ->
      case pagination_model.next_cursor(model.logs_page) {
        option.Some(cursor) ->
          load_job_logs_page(
            model,
            pagination_model.AfterPage(
              cursor: cursor,
              limit: job_logs_page_limit,
            ),
          )
        option.None -> #(model, effect.none())
      }

    PreviousLogsPageClicked ->
      case pagination_model.previous_cursor(model.logs_page) {
        option.Some(cursor) ->
          load_job_logs_page(
            model,
            pagination_model.BeforePage(
              cursor: cursor,
              limit: job_logs_page_limit,
            ),
          )
        option.None -> #(model, effect.none())
      }

    OpenCreateJobClicked ->
      case model.job {
        option.Some(job) -> #(
          Model(
            ..model,
            create_job_editor: option.Some(editor_from_job(job, clock.now())),
          ),
          app_dialog.open(create_job_dialog_id),
        )
        option.None -> #(model, effect.none())
      }

    CreateJobDialogClosed -> #(
      Model(..model, create_job_editor: option.None),
      effect.none(),
    )

    CreateJobCancelled -> #(
      Model(..model, create_job_editor: option.None),
      app_dialog.close(create_job_dialog_id),
    )

    CreateJobSubmitted ->
      case model.create_job_editor {
        option.Some(editor) ->
          case editor_to_request(editor) {
            Ok(request) -> #(
              Model(
                ..model,
                create_job_editor: option.Some(
                  CreateJobEditor(..editor, state: CreateJobSaving),
                ),
              ),
              api.create_admin_job(request, CreateJobFinished),
            )
            Error(message) -> #(
              Model(
                ..model,
                create_job_editor: option.Some(
                  CreateJobEditor(..editor, state: CreateJobError(message)),
                ),
              ),
              effect.none(),
            )
          }
        option.None -> #(model, effect.none())
      }

    CreateJobFinished(result) ->
      case model.create_job_editor {
        option.Some(editor) ->
          case result {
            api.ApiSuccess(response) -> #(
              Model(..model, create_job_editor: option.None),
              effect.batch([
                app_dialog.close(create_job_dialog_id),
                navigate_to_job(response.job.id),
              ]),
            )
            api.ApiFailure(error) -> #(
              Model(
                ..model,
                create_job_editor: option.Some(
                  CreateJobEditor(
                    ..editor,
                    state: CreateJobError(error.message),
                  ),
                ),
              ),
              effect.none(),
            )
            api.HttpFailure(_) -> #(
              Model(
                ..model,
                create_job_editor: option.Some(
                  CreateJobEditor(
                    ..editor,
                    state: CreateJobError("Could not create job."),
                  ),
                ),
              ),
              effect.none(),
            )
          }
        option.None -> #(model, effect.none())
      }

    CreateJobPayloadChanged(value) -> #(
      update_create_job_editor(model, fn(editor) {
        CreateJobEditor(
          ..editor,
          draft: CreateJobDraft(..editor.draft, payload: value),
          state: reset_create_job_state(editor.state),
        )
      }),
      effect.none(),
    )

    CreateJobMaxAttemptsChanged(value) -> #(
      update_create_job_editor(model, fn(editor) {
        CreateJobEditor(
          ..editor,
          draft: CreateJobDraft(..editor.draft, max_attempts: value),
          state: reset_create_job_state(editor.state),
        )
      }),
      effect.none(),
    )

    CreateJobTimeoutSecondsChanged(value) -> #(
      update_create_job_editor(model, fn(editor) {
        CreateJobEditor(
          ..editor,
          draft: CreateJobDraft(..editor.draft, timeout_seconds: value),
          state: reset_create_job_state(editor.state),
        )
      }),
      effect.none(),
    )

    CreateJobRunDateChanged(value) -> #(
      update_create_job_editor(model, fn(editor) {
        CreateJobEditor(
          ..editor,
          draft: CreateJobDraft(..editor.draft, run_date: value),
          state: reset_create_job_state(editor.state),
        )
      }),
      effect.none(),
    )

    CreateJobRunTimeChanged(value) -> #(
      update_create_job_editor(model, fn(editor) {
        CreateJobEditor(
          ..editor,
          draft: CreateJobDraft(..editor.draft, run_time: value),
          state: reset_create_job_state(editor.state),
        )
      }),
      effect.none(),
    )
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  html.div([], [
    admin_ui.page_with_panel_class(
      panel_class: "admin-job-page",
      title: "Job detail",
      intro: "Inspect one job execution, its scheduling metadata, and any stored payload or error output.",
      actions: [
        html.button(
          [
            attribute.class("admin-page__button"),
            attribute.type_("button"),
            attribute.disabled(option.is_none(model.job)),
            event.on_click(OpenCreateJobClicked),
          ],
          [html.text("Start new job")],
        ),
      ],
      content: [job_status_view(model), detail_view(model, now)],
    ),
    create_job_dialog(model),
  ])
}

fn job_status_view(model: Model) -> Element(Msg) {
  case model.job_status {
    NotLoaded | Ready -> admin_ui.status("")
    Loading -> admin_ui.status("Loading job...")
    LoadError(message) -> admin_ui.error_status(message)
  }
}

fn detail_view(model: Model, now: Timestamp) -> Element(Msg) {
  case model.job, model.job_status {
    option.None, Loading -> admin_ui.empty_state("Loading job...")
    option.None, _ -> admin_ui.empty_state("This job could not be loaded.")
    option.Some(job), _ ->
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class(admin_ui.summary_grid_class())], [
          admin_ui.summary_card(
            "Status",
            admin_job_ui.status_text(job.status, job.overdue),
          ),
          admin_ui.summary_card(
            "Run at",
            timestamp_helpers.relative_label(job.run_at, now),
          ),
          admin_ui.summary_card(
            "Attempts",
            int.to_string(job.attempts)
              <> " / "
              <> int.to_string(job.max_attempts),
          ),
        ]),
        admin_ui.section(
          title: "Metadata",
          copy: "Identifiers and timestamps captured for this execution.",
          content: html.div([attribute.class(admin_ui.detail_grid_class())], [
            admin_ui.detail_item("Job ID", uuid.to_string(job.id)),
            admin_ui.detail_item(
              "Request ID",
              admin_format.optional_uuid(job.request_id),
            ),
            periodic_job_detail_item(job.periodic_job_id),
            admin_ui.detail_item("Job type", job.job_type),
            admin_ui.detail_item(
              "Status",
              admin_job_ui.status_text(job.status, job.overdue),
            ),
            admin_ui.detail_item("Overdue", bool_text(job.overdue)),
            admin_ui.detail_item(
              "Run at",
              admin_format.format_timestamp(job.run_at),
            ),
            admin_ui.detail_item(
              "Started at",
              admin_format.optional_timestamp(job.started_at),
            ),
            admin_ui.detail_item(
              "Completed at",
              admin_format.optional_timestamp(job.completed_at),
            ),
            admin_ui.detail_item(
              "Created at",
              admin_format.format_timestamp(job.created_at),
            ),
            admin_ui.detail_item(
              "Updated at",
              admin_format.format_timestamp(job.updated_at),
            ),
          ]),
        ),
        job_logs_group(model, now),
        admin_ui.section(
          title: "Notes",
          copy: "Current operator-facing interpretation of this job state.",
          content: html.div([attribute.class("admin-page__policy")], [
            html.p([attribute.class("admin-job-page__body-text")], [
              html.text(note_text(job)),
            ]),
          ]),
        ),
        admin_ui.section(
          title: "Payload",
          copy: "Stored raw payload string for this job, if any.",
          content: code_block(admin_format.optional_text(job.payload)),
        ),
        admin_ui.section(
          title: "Last error",
          copy: "Latest persisted failure message, if one was recorded.",
          content: code_block(admin_format.optional_text(job.last_error)),
        ),
      ])
  }
}

fn job_logs_group(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.logs_page)
  let count_text =
    int.to_string(list.length(rows)) <> " log entries shown for this job."

  html.div([attribute.class("admin-page__group")], [
    html.div([attribute.class("admin-page__group-header")], [
      html.div([], [
        html.h3([attribute.class("admin-page__group-title")], [
          html.text("Logs"),
        ]),
        html.p([attribute.class("admin-page__group-copy")], [
          html.text(count_text),
        ]),
      ]),
      html.div(
        [attribute.class("admin-page__actions")],
        admin_ui.cursor_pagination_actions(
          model.logs_page,
          PreviousLogsPageClicked,
          NextLogsPageClicked,
        ),
      ),
    ]),
    logs_status_view(model),
    job_logs_table(model, now),
  ])
}

fn logs_status_view(model: Model) -> Element(Msg) {
  case model.logs_status {
    NotLoaded | Ready -> admin_ui.status("")
    Loading -> admin_ui.status("Loading job logs...")
    LoadError(message) -> admin_ui.error_status(message)
  }
}

fn job_logs_table(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.logs_page)

  case rows, model.logs_status {
    [], Loading -> admin_ui.empty_state("Loading job logs...")
    [], _ -> admin_ui.empty_state("No job logs were found for this job.")

    _, _ ->
      admin_table.table(job_log_columns(), {
        rows |> list.map(fn(log) { job_log_row(log, now) })
      })
  }
}

fn job_log_row(
  log: job_log_dto.JobLogResponse,
  now: Timestamp,
) -> Element(Msg) {
  admin_table.row([
    admin_table.linked_primary_cell(
      log_id_column(),
      [route.href(route.Admin(route.AdminJobLog(log.id)))],
      string_helpers.truncate_stem_middle(uuid.to_string(log.id), 18),
      option.None,
    ),
    admin_table.primary_cell(
      when_column(),
      timestamp_helpers.relative_label(log.created_at, now),
    ),
    admin_table.value_cell(attempt_column(), int.to_string(log.attempt)),
    admin_table.value_cell(
      duration_column(),
      duration_label.duration_in_ms_label(log.duration_ns),
    ),
    admin_table.cell(error_column(), [admin_ui.error_badge(log.has_error)]),
    admin_table.open_link_cell([
      route.href(route.Admin(route.AdminJobLog(log.id))),
    ]),
  ])
}

fn job_log_columns() -> List(admin_table.Column) {
  [
    log_id_column(),
    when_column(),
    attempt_column(),
    duration_column(),
    error_column(),
    open_column(),
  ]
}

fn log_id_column() -> admin_table.Column {
  admin_table.column("Log ID")
}

fn when_column() -> admin_table.Column {
  admin_table.column("When")
}

fn attempt_column() -> admin_table.Column {
  admin_table.fit_column("Attempt")
}

fn duration_column() -> admin_table.Column {
  admin_table.fit_column("Duration")
}

fn error_column() -> admin_table.Column {
  admin_table.fit_column("Error")
}

fn open_column() -> admin_table.Column {
  admin_table.open_column()
}

fn load_job_logs_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, Effect(Msg)) {
  #(Model(..model, logs_status: Loading), get_job_logs(model, pagination))
}

fn get_job_logs(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> Effect(Msg) {
  api.get_admin_job_logs(
    job_log_dto.ListJobLogsRequest(
      pagination: pagination,
      request_id: option.None,
      job_id: option.Some(model.job_id),
      error_filter: job_log_dto.AllJobLogs,
    ),
    JobLogsLoaded,
  )
}

fn linked_detail_item(
  label: String,
  value: String,
  destination: route.Route,
) -> Element(Msg) {
  admin_ui.detail_link_item(label, value, [route.href(destination)])
}

fn periodic_job_detail_item(value: option.Option(uuid.Uuid)) -> Element(Msg) {
  case value {
    option.Some(id) ->
      linked_detail_item(
        "Periodic job ID",
        uuid.to_string(id),
        route.Admin(route.AdminPeriodicJob(id)),
      )
    option.None -> admin_ui.detail_item("Periodic job ID", "None")
  }
}

fn code_block(value: String) -> Element(Msg) {
  admin_ui.code_block(value)
}

fn create_job_dialog(model: Model) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(create_job_dialog_id),
      attribute.class("app-dialog admin-page__dialog"),
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
  admin_ui.dialog_form([event.on_submit(fn(_) { CreateJobSubmitted })], [
    admin_ui.dialog_section([
      admin_ui.dialog_header_with_close(
        title: "Start new job",
        copy: "Seeded from the selected job, but this creates a fresh queued job with the values below.",
        close_attributes: [event.on_click(CreateJobCancelled)],
        close_label: "Close",
      ),
      html.div([attribute.class("admin-page__modal-grid")], [
        admin_ui.detail_item(
          "Source job ID",
          uuid.to_string(editor.source_job_id),
        ),
        admin_ui.detail_item("Job type", editor.draft.job_type),
        admin_ui.detail_item(
          "Periodic job ID",
          admin_format.optional_uuid(editor.draft.periodic_job_id),
        ),
      ]),
      html.div([attribute.class("admin-page__modal-grid")], [
        admin_ui.text_input_with_attrs(
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
        admin_ui.text_input_with_attrs(
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
        admin_ui.text_input_with_attrs(
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
        admin_ui.text_input_with_attrs(
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
      admin_ui.textarea_input_with_attrs(
        label: "Payload",
        help: "Raw payload string. Leave empty to create the job without a payload.",
        value: editor.draft.payload,
        rows: 6,
        field_class: "admin-periodic-jobs-page__payload-field",
        textarea_class: "admin-periodic-jobs-page__payload-input",
        textarea_attributes: [],
        on_input: CreateJobPayloadChanged,
      ),
      admin_ui.form_status_block(create_job_status(editor.state)),
    ]),
    admin_ui.dialog_actions([
      admin_ui.dialog_cancel_button(
        [
          attribute.type_("button"),
          event.on_click(CreateJobCancelled),
        ],
        "Cancel",
      ),
      admin_ui.dialog_primary_button(
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
    CreateJobIdle -> admin_ui.status("")
    CreateJobSaving -> admin_ui.status("Creating job...")
    CreateJobError(message) -> admin_ui.error_status(message)
    CreateJobSaved(job) ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Created new job successfully. "),
        html.a([route.href(route.Admin(route.AdminJob(job.id)))], [
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

fn navigate_to_job(job_id: uuid.Uuid) -> Effect(Msg) {
  modem.push(
    route.to_string(route.Admin(route.AdminJob(job_id))),
    option.None,
    option.None,
  )
}

fn empty_logs_page() -> pagination_model.CursorPage(job_log_dto.JobLogResponse) {
  pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
}

fn loading_status(status: Status) -> Status {
  case status {
    NotLoaded -> Loading
    Loading | Ready | LoadError(_) -> status
  }
}

fn reset_create_job_state(state: CreateJobState) -> CreateJobState {
  case state {
    CreateJobSaving | CreateJobIdle -> CreateJobIdle
    CreateJobError(_) | CreateJobSaved(_) -> CreateJobIdle
  }
}

fn update_create_job_editor(
  model: Model,
  update: fn(CreateJobEditor) -> CreateJobEditor,
) -> Model {
  case model.create_job_editor {
    option.Some(editor) ->
      Model(..model, create_job_editor: option.Some(update(editor)))
    option.None -> model
  }
}

fn editor_from_job(
  job: job_dto.JobDetailResponse,
  initial_run_at: Timestamp,
) -> CreateJobEditor {
  CreateJobEditor(
    source_job_id: job.id,
    draft: CreateJobDraft(
      periodic_job_id: job.periodic_job_id,
      job_type: job.job_type,
      payload: option.unwrap(job.payload, ""),
      max_attempts: int.to_string(job.max_attempts),
      timeout_seconds: int.to_string(job.timeout_seconds),
      run_date: local_datetime.timestamp_to_local_date_input(initial_run_at),
      run_time: local_datetime.timestamp_to_local_time_input(initial_run_at),
    ),
    state: CreateJobIdle,
  )
}

fn editor_to_request(
  editor: CreateJobEditor,
) -> Result(job_dto.CreateJobRequest, String) {
  use max_attempts <- result.try(admin_format.parse_positive_int(
    editor.draft.max_attempts,
    "Max attempts",
  ))
  use timeout_seconds <- result.try(admin_format.parse_positive_int(
    editor.draft.timeout_seconds,
    "Timeout seconds",
  ))
  use run_at <- result.try(parse_local_run_at(
    editor.draft.run_date,
    editor.draft.run_time,
  ))

  Ok(job_dto.CreateJobRequest(
    periodic_job_id: editor.draft.periodic_job_id,
    job_type: editor.draft.job_type,
    payload: optional_payload(editor.draft.payload),
    max_attempts: max_attempts,
    timeout_seconds: timeout_seconds,
    run_at: run_at,
  ))
}

fn parse_local_run_at(date: String, time: String) -> Result(Timestamp, String) {
  case date == "" || time == "" {
    True -> Error("Run date and time are required.")
    False -> {
      let milliseconds =
        local_datetime.local_date_time_to_unix_milliseconds(date, time)

      case milliseconds < 0 {
        True -> Error("Run date or time is invalid.")
        False -> Ok(timestamp_helpers.from_unix_milliseconds(milliseconds))
      }
    }
  }
}

fn optional_payload(value: String) -> option.Option(String) {
  case value == "" {
    True -> option.None
    False -> option.Some(value)
  }
}

fn bool_text(value: Bool) -> String {
  case value {
    True -> "Yes"
    False -> "No"
  }
}

fn note_text(job: job_dto.JobDetailResponse) -> String {
  case job.last_error {
    option.Some(last_error) -> last_error
    option.None ->
      case job.status {
        "pending" ->
          case job.overdue {
            True -> "Queued past its scheduled run time."
            False -> "Queued"
          }
        "running" -> "Currently being processed."
        "failed" -> "Failed without a stored error message."
        "done" -> "Completed successfully."
        _ -> ""
      }
  }
}
