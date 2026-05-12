import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/job_dto
import glot_core/admin/periodic_job_dto
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/local_datetime
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

pub type Model {
  Model(
    id: uuid.Uuid,
    periodic_job: option.Option(PeriodicJobEditor),
    status: Status,
    recent_jobs: List(job_dto.JobResponse),
    jobs_status: Status,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type PeriodicJobEditor {
  PeriodicJobEditor(
    id: uuid.Uuid,
    job_type: String,
    saved: PeriodicJobFields,
    draft: PeriodicJobFields,
    metadata: PeriodicJobMetadata,
    state: EditorState,
  )
}

pub type PeriodicJobFields {
  PeriodicJobFields(
    payload: String,
    interval_seconds: String,
    enabled: Bool,
    next_run_date: String,
    next_run_time: String,
  )
}

pub type PeriodicJobMetadata {
  PeriodicJobMetadata(
    next_run_at: timestamp.Timestamp,
    last_enqueued_at: option.Option(timestamp.Timestamp),
    last_enqueue_error: option.Option(String),
    created_at: timestamp.Timestamp,
    updated_at: timestamp.Timestamp,
  )
}

pub type EditorState {
  Idle
  Saving
  Saved
  SaveError(String)
}

pub type Msg {
  PeriodicJobLoaded(api.ApiResponse(periodic_job_dto.GetPeriodicJobResponse))
  PayloadChanged(String)
  IntervalSecondsChanged(String)
  EnabledToggled
  NextRunDateChanged(String)
  NextRunTimeChanged(String)
  ResetClicked
  SaveClicked
  SaveFinished(api.ApiResponse(periodic_job_dto.UpdatePeriodicJobResponse))
  RecentJobsLoaded(api.ApiResponse(job_dto.ListJobsResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(
    Model(
      id: id,
      periodic_job: option.None,
      status: NotLoaded,
      recent_jobs: [],
      jobs_status: NotLoaded,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  let should_load_job = model.status == NotLoaded
  let should_load_recent_jobs = model.jobs_status == NotLoaded

  case should_load_job || should_load_recent_jobs {
    True -> #(
      Model(
        ..model,
        status: case should_load_job {
          True -> Loading
          False -> model.status
        },
        jobs_status: case should_load_recent_jobs {
          True -> Loading
          False -> model.jobs_status
        },
      ),
      effect.batch([
        case should_load_job {
          True ->
            api.get_admin_periodic_job(
              periodic_job_dto.GetPeriodicJobRequest(id: model.id),
              PeriodicJobLoaded,
            )
          False -> effect.none()
        },
        case should_load_recent_jobs {
          True -> load_recent_jobs(model.id)
          False -> effect.none()
        },
      ]),
    )
    False -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    PeriodicJobLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            periodic_job: option.Some(editor_from_response(
              response.periodic_job,
            )),
            status: Ready,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load periodic job.")),
          effect.none(),
        )
      }

    PayloadChanged(value) -> #(
      update_editor_model(model, fn(editor) {
        PeriodicJobEditor(
          ..editor,
          draft: PeriodicJobFields(..editor.draft, payload: value),
          state: Idle,
        )
      }),
      effect.none(),
    )

    IntervalSecondsChanged(value) -> #(
      update_editor_model(model, fn(editor) {
        PeriodicJobEditor(
          ..editor,
          draft: PeriodicJobFields(..editor.draft, interval_seconds: value),
          state: Idle,
        )
      }),
      effect.none(),
    )

    EnabledToggled -> #(
      update_editor_model(model, fn(editor) {
        PeriodicJobEditor(
          ..editor,
          draft: PeriodicJobFields(
            ..editor.draft,
            enabled: !editor.draft.enabled,
          ),
          state: Idle,
        )
      }),
      effect.none(),
    )

    NextRunDateChanged(value) -> #(
      update_editor_model(model, fn(editor) {
        PeriodicJobEditor(
          ..editor,
          draft: PeriodicJobFields(..editor.draft, next_run_date: value),
          state: Idle,
        )
      }),
      effect.none(),
    )

    NextRunTimeChanged(value) -> #(
      update_editor_model(model, fn(editor) {
        PeriodicJobEditor(
          ..editor,
          draft: PeriodicJobFields(..editor.draft, next_run_time: value),
          state: Idle,
        )
      }),
      effect.none(),
    )

    ResetClicked -> #(
      update_editor_model(model, fn(editor) {
        PeriodicJobEditor(..editor, draft: editor.saved, state: Idle)
      }),
      effect.none(),
    )

    SaveClicked ->
      case model.periodic_job {
        option.None -> #(model, effect.none())
        option.Some(editor) ->
          case editor_to_request(editor) {
            Ok(request) -> #(
              update_editor_model(model, fn(current) {
                PeriodicJobEditor(..current, state: Saving)
              }),
              api.update_admin_periodic_job(request, SaveFinished),
            )
            Error(message) -> #(
              update_editor_model(model, fn(current) {
                PeriodicJobEditor(..current, state: SaveError(message))
              }),
              effect.none(),
            )
          }
      }

    SaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            periodic_job: option.Some(editor_from_response(
              response.periodic_job,
            )),
            status: Ready,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          update_editor_model(model, fn(editor) {
            PeriodicJobEditor(..editor, state: SaveError(error.message))
          }),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          update_editor_model(model, fn(editor) {
            PeriodicJobEditor(
              ..editor,
              state: SaveError("Could not save periodic job."),
            )
          }),
          effect.none(),
        )
      }

    RecentJobsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            recent_jobs: pagination_model.items(response.page),
            jobs_status: Ready,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, jobs_status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, jobs_status: LoadError("Could not load recent jobs.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model, now: timestamp.Timestamp) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Periodic job detail"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "Inspect one scheduler definition and update cadence, enabled state, next enqueue time, or payload.",
              ),
            ]),
          ]),
        ]),
        status_banner(model.status),
        detail_view(model, now),
      ]),
    ]),
  ])
}

fn detail_view(model: Model, now: timestamp.Timestamp) -> Element(Msg) {
  case model.periodic_job, model.status {
    option.None, Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading periodic job..."),
      ])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This periodic job could not be loaded."),
      ])
    option.Some(editor), _ -> periodic_job_view(model, editor, now)
  }
}

fn periodic_job_view(
  model: Model,
  editor: PeriodicJobEditor,
  now: timestamp.Timestamp,
) -> Element(Msg) {
  let save_disabled = editor.state == Saving || !is_dirty(editor)

  html.div([attribute.class("admin-job-page__content")], [
    html.div([attribute.class("admin-job-page__summary-grid")], [
      summary_card(
        "Status",
        enabled_text(editor.saved.enabled),
        schedule_status(editor),
      ),
      summary_card(
        "Next run",
        timestamp_helpers.relative_label(editor.metadata.next_run_at, now),
        "Updated "
          <> timestamp_helpers.relative_label(editor.metadata.updated_at, now),
      ),
      summary_card(
        "Cadence",
        editor.saved.interval_seconds <> "s",
        "Created "
          <> timestamp_helpers.relative_label(editor.metadata.created_at, now),
      ),
    ]),
    html.div([attribute.class("admin-page__group")], [
      html.div([attribute.class("admin-page__group-header")], [
        html.h3([attribute.class("admin-page__group-title")], [
          html.text("Metadata"),
        ]),
        html.p([attribute.class("admin-page__group-copy")], [
          html.text(
            "Operational timestamps and scheduler state for this periodic definition.",
          ),
        ]),
      ]),
      html.div([attribute.class("admin-job-page__detail-grid")], [
        detail_item("Periodic job ID", uuid.to_string(editor.id)),
        detail_item("Type", editor.job_type),
        detail_item("Enabled", enabled_text(editor.saved.enabled)),
        detail_item(
          "Next run at",
          format_timestamp(editor.metadata.next_run_at),
        ),
        detail_item(
          "Last enqueued at",
          optional_timestamp(editor.metadata.last_enqueued_at),
        ),
        detail_item("Created at", format_timestamp(editor.metadata.created_at)),
        detail_item("Updated at", format_timestamp(editor.metadata.updated_at)),
        detail_item(
          "Last enqueue error",
          optional_text(editor.metadata.last_enqueue_error),
        ),
      ]),
    ]),
    recent_jobs_group(model, now),
    html.div([attribute.class("admin-page__group")], [
      html.div([attribute.class("admin-page__group-header")], [
        html.h3([attribute.class("admin-page__group-title")], [
          html.text("Settings"),
        ]),
        html.p([attribute.class("admin-page__group-copy")], [
          html.text("Edit the scheduler fields stored for this periodic job."),
        ]),
      ]),
      html.div([attribute.class("admin-page__policy")], [
        html.div([attribute.class("admin-page__policy-header")], [
          html.div([], [
            html.h3([attribute.class("admin-page__policy-title")], [
              html.text(job_type_label(editor.job_type)),
            ]),
            html.p([attribute.class("admin-page__policy-subtitle")], [
              html.text("Job type is fixed; the fields below are editable."),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-header-actions")], [
            status_badge(editor),
          ]),
        ]),
        html.div([attribute.class("admin-page__field-grid")], [
          text_input(
            label: "Interval seconds",
            help: "Scheduler cadence in seconds. Must be greater than zero.",
            value: editor.draft.interval_seconds,
            input_type: "text",
            extra_attributes: [],
            on_input: IntervalSecondsChanged,
          ),
          text_input(
            label: "Next run date",
            help: "Local calendar date for the next enqueue time.",
            value: editor.draft.next_run_date,
            input_type: "date",
            extra_attributes: [],
            on_input: NextRunDateChanged,
          ),
          text_input(
            label: "Next run time",
            help: "Local time for the next enqueue time. It is converted back to UTC when saved.",
            value: editor.draft.next_run_time,
            input_type: "time",
            extra_attributes: [attribute.attribute("step", "1")],
            on_input: NextRunTimeChanged,
          ),
          toggle_field(editor),
          textarea_input(
            label: "Payload JSON",
            help: "Leave blank for no payload. Saved as raw JSON text without frontend validation.",
            value: editor.draft.payload,
            on_input: PayloadChanged,
          ),
        ]),
        html.div([attribute.class("admin-page__policy-footer")], [
          section_message(editor),
          html.div([attribute.class("admin-page__policy-actions")], [
            admin_ui.secondary_button(
              [
                attribute.type_("button"),
                attribute.disabled(editor.state == Saving || !is_dirty(editor)),
                event.on_click(ResetClicked),
              ],
              "Reset",
            ),
            html.button(
              [
                attribute.type_("button"),
                attribute.class("admin-page__button"),
                attribute.disabled(save_disabled),
                event.on_click(SaveClicked),
              ],
              [
                html.text(case editor.state {
                  Saving -> "Saving..."
                  _ -> "Save"
                }),
              ],
            ),
          ]),
        ]),
      ]),
    ]),
  ])
}

fn load_recent_jobs(id: uuid.Uuid) -> Effect(Msg) {
  api.get_admin_jobs(
    job_dto.ListJobsRequest(
      pagination: pagination_model.InitialPage(limit: 10),
      status_filter: job_dto.AllStatuses,
      job_type_filter: option.None,
      periodic_job_id: option.Some(id),
    ),
    RecentJobsLoaded,
  )
}

fn recent_jobs_group(model: Model, now: timestamp.Timestamp) -> Element(Msg) {
  let count_text =
    int.to_string(list.length(model.recent_jobs))
    <> " recent jobs shown for this periodic definition."

  html.div([attribute.class("admin-page__group")], [
    html.div([attribute.class("admin-page__group-header")], [
      html.h3([attribute.class("admin-page__group-title")], [
        html.text("Recent jobs"),
      ]),
      html.p([attribute.class("admin-page__group-copy")], [
        html.text(count_text),
      ]),
    ]),
    recent_jobs_status_view(model.jobs_status),
    recent_jobs_table(model.recent_jobs, model.jobs_status, now),
  ])
}

fn recent_jobs_status_view(status: Status) -> Element(Msg) {
  case status {
    NotLoaded | Ready -> html.div([], [])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading recent jobs..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn recent_jobs_table(
  recent_jobs: List(job_dto.JobResponse),
  status: Status,
  now: timestamp.Timestamp,
) -> Element(Msg) {
  case recent_jobs, status {
    [], Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading recent jobs..."),
      ])
    [], _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No jobs were found for this periodic definition."),
      ])
    _, _ ->
      admin_table.table(recent_job_columns(), {
        recent_jobs |> list.map(fn(job) { recent_job_row(job, now) })
      })
  }
}

fn recent_job_row(
  job: job_dto.JobResponse,
  now: timestamp.Timestamp,
) -> Element(Msg) {
  admin_table.row([
    admin_table.cell(job_column(), [
      html.span([attribute.class("admin-table__value--primary")], [
        html.text(job.job_type),
      ]),
    ]),
    admin_table.cell(status_column(), [recent_job_status_badge(job)]),
    admin_table.cell(schedule_column(), [
      html.span([attribute.class("admin-table__value--primary")], [
        html.text(timestamp_helpers.relative_label(job.run_at, now)),
      ]),
    ]),
    admin_table.cell(attempts_column(), [
      html.span([attribute.class("admin-table__value--primary")], [
        html.text(
          int.to_string(job.attempts)
          <> " / "
          <> int.to_string(job.max_attempts),
        ),
      ]),
    ]),
    admin_table.cell(open_column(), [
      admin_ui.secondary_link([route.href(route.AdminJob(job.id))], "Open"),
    ]),
  ])
}

fn recent_job_columns() -> List(admin_table.Column) {
  [
    job_column(),
    status_column(),
    schedule_column(),
    attempts_column(),
    open_column(),
  ]
}

fn job_column() -> admin_table.Column {
  admin_table.column("Job")
}

fn status_column() -> admin_table.Column {
  admin_table.fit_column("Status")
}

fn schedule_column() -> admin_table.Column {
  admin_table.column("Schedule")
}

fn attempts_column() -> admin_table.Column {
  admin_table.fit_column("Attempts")
}

fn open_column() -> admin_table.Column {
  admin_table.action_column("Open")
}

fn recent_job_status_badge(job: job_dto.JobResponse) -> Element(Msg) {
  case job.status, job.overdue {
    "failed", _ ->
      admin_ui.badge(recent_job_status_text(job), admin_ui.DangerTone)
    "running", _ ->
      admin_ui.badge(recent_job_status_text(job), admin_ui.WarningTone)
    "pending", True ->
      admin_ui.badge(recent_job_status_text(job), admin_ui.DangerTone)
    "pending", False ->
      admin_ui.badge(recent_job_status_text(job), admin_ui.InfoTone)
    "done", _ ->
      admin_ui.badge(recent_job_status_text(job), admin_ui.SuccessTone)
    _, _ -> admin_ui.badge(recent_job_status_text(job), admin_ui.NeutralTone)
  }
}

fn recent_job_status_text(job: job_dto.JobResponse) -> String {
  case job.status, job.overdue {
    "pending", True -> "Pending • overdue"
    "pending", False -> "Pending"
    "running", _ -> "Running"
    "failed", _ -> "Failed"
    "done", _ -> "Done"
    value, _ -> value
  }
}

fn update_editor_model(
  model: Model,
  update: fn(PeriodicJobEditor) -> PeriodicJobEditor,
) -> Model {
  case model.periodic_job {
    option.None -> model
    option.Some(editor) ->
      Model(..model, periodic_job: option.Some(update(editor)))
  }
}

fn status_banner(status: Status) -> Element(Msg) {
  case status {
    NotLoaded | Ready -> html.div([], [])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading periodic job..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn toggle_field(editor: PeriodicJobEditor) -> Element(Msg) {
  html.div([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [
      html.text("Enabled"),
    ]),
    html.button(
      [
        attribute.type_("button"),
        attribute.class(toggle_button_class(editor.draft.enabled)),
        event.on_click(EnabledToggled),
      ],
      [html.text(enabled_text(editor.draft.enabled))],
    ),
    html.span([attribute.class("admin-page__field-help")], [
      html.text(
        "Disabled definitions remain in storage but the scheduler will skip them.",
      ),
    ]),
  ])
}

fn section_message(editor: PeriodicJobEditor) -> Element(Msg) {
  case editor.state {
    SaveError(message) ->
      html.p(
        [
          attribute.class(
            "admin-page__policy-status admin-page__policy-status--error",
          ),
        ],
        [html.text(message)],
      )
    Saving ->
      html.p([attribute.class("admin-page__policy-status")], [
        html.text("Saving changes..."),
      ])
    Saved ->
      html.p([attribute.class("admin-page__policy-status")], [
        html.text("Periodic job saved."),
      ])
    Idle ->
      case is_dirty(editor) {
        True ->
          html.p(
            [
              attribute.class(
                "admin-page__policy-status admin-page__policy-status--dirty",
              ),
            ],
            [html.text("Changes not saved yet.")],
          )
        False ->
          html.p([attribute.class("admin-page__policy-status")], [
            html.text("Scheduler definition is in sync."),
          ])
      }
  }
}

fn status_badge(editor: PeriodicJobEditor) -> Element(Msg) {
  case editor.state, is_dirty(editor) {
    Idle, False -> html.div([], [])
    _, _ ->
      html.span([attribute.class(status_badge_class(editor))], [
        html.text(status_badge_text(editor)),
      ])
  }
}

fn status_badge_text(editor: PeriodicJobEditor) -> String {
  case editor.state {
    SaveError(_) -> "Error"
    Saving -> "Saving"
    Saved -> "Saved"
    Idle ->
      case is_dirty(editor) {
        True -> "Unsaved"
        False -> ""
      }
  }
}

fn status_badge_class(editor: PeriodicJobEditor) -> String {
  case editor.state {
    SaveError(_) -> "admin-page__version admin-page__version--error"
    Saving | Saved -> "admin-page__version admin-page__version--success"
    Idle ->
      case is_dirty(editor) {
        True -> "admin-page__version admin-page__version--dirty"
        False -> "admin-page__version"
      }
  }
}

fn text_input(
  label label: String,
  help help: String,
  value value: String,
  input_type input_type: String,
  extra_attributes extra_attributes: List(attribute.Attribute(Msg)),
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [
      html.text(label),
    ]),
    html.input([
      attribute.type_(input_type),
      attribute.class("admin-page__input"),
      attribute.value(value),
      event.on_input(on_input),
      ..extra_attributes
    ]),
    html.span([attribute.class("admin-page__field-help")], [
      html.text(help),
    ]),
  ])
}

fn textarea_input(
  label label: String,
  help help: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label(
    [
      attribute.class(
        "admin-page__field admin-periodic-jobs-page__payload-field",
      ),
    ],
    [
      html.span([attribute.class("admin-page__field-label")], [
        html.text(label),
      ]),
      html.textarea(
        [
          attribute.class(
            "admin-page__input admin-periodic-jobs-page__payload-input",
          ),
          attribute.rows(6),
          event.on_input(on_input),
        ],
        value,
      ),
      html.span([attribute.class("admin-page__field-help")], [
        html.text(help),
      ]),
    ],
  )
}

fn summary_card(title: String, value: String, meta: String) -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "admin-page__policy admin-periodic-jobs-page__summary-card",
      ),
    ],
    [
      html.span([attribute.class("admin-job-page__eyebrow")], [html.text(title)]),
      html.span([attribute.class("admin-job-page__summary-value")], [
        html.text(value),
      ]),
      html.p([attribute.class("admin-job-page__meta")], [html.text(meta)]),
    ],
  )
}

fn detail_item(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-job-page__detail-item")], [
    html.span([attribute.class("admin-job-page__eyebrow")], [html.text(label)]),
    html.span([attribute.class("admin-job-page__detail-value")], [
      html.text(value),
    ]),
  ])
}

fn editor_from_response(
  periodic_job: periodic_job_dto.PeriodicJobResponse,
) -> PeriodicJobEditor {
  let fields = fields_from_response(periodic_job)

  PeriodicJobEditor(
    id: periodic_job.id,
    job_type: periodic_job.job_type,
    saved: fields,
    draft: fields,
    metadata: PeriodicJobMetadata(
      next_run_at: periodic_job.next_run_at,
      last_enqueued_at: periodic_job.last_enqueued_at,
      last_enqueue_error: periodic_job.last_enqueue_error,
      created_at: periodic_job.created_at,
      updated_at: periodic_job.updated_at,
    ),
    state: Idle,
  )
}

fn fields_from_response(
  periodic_job: periodic_job_dto.PeriodicJobResponse,
) -> PeriodicJobFields {
  PeriodicJobFields(
    payload: option.unwrap(periodic_job.payload, ""),
    interval_seconds: int.to_string(periodic_job.interval_seconds),
    enabled: periodic_job.enabled,
    next_run_date: local_datetime.timestamp_to_local_date_input(
      periodic_job.next_run_at,
    ),
    next_run_time: local_datetime.timestamp_to_local_time_input(
      periodic_job.next_run_at,
    ),
  )
}

fn is_dirty(editor: PeriodicJobEditor) -> Bool {
  editor.saved != editor.draft
}

fn editor_to_request(
  editor: PeriodicJobEditor,
) -> Result(periodic_job_dto.UpdatePeriodicJobRequest, String) {
  use interval_seconds <- result.try(parse_positive_int(
    editor.draft.interval_seconds,
    "Interval seconds",
  ))
  use next_run_at <- result.try(parse_local_next_run_at(
    editor.draft.next_run_date,
    editor.draft.next_run_time,
  ))

  Ok(periodic_job_dto.UpdatePeriodicJobRequest(
    id: editor.id,
    payload: optional_payload(editor.draft.payload),
    interval_seconds: interval_seconds,
    enabled: editor.draft.enabled,
    next_run_at: next_run_at,
  ))
}

fn parse_positive_int(value: String, label: String) -> Result(Int, String) {
  use parsed <- result.try(
    int.parse(value)
    |> result.map_error(fn(_) { label <> " must be a whole number." }),
  )

  case parsed > 0 {
    True -> Ok(parsed)
    False -> Error(label <> " must be greater than zero.")
  }
}

fn parse_local_next_run_at(
  date: String,
  time: String,
) -> Result(timestamp.Timestamp, String) {
  case date == "" || time == "" {
    True -> Error("Next run date and time are required.")
    False -> {
      let milliseconds =
        local_datetime.local_date_time_to_unix_milliseconds(date, time)

      case milliseconds < 0 {
        True -> Error("Next run date or time is invalid.")
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

fn optional_timestamp(value: option.Option(timestamp.Timestamp)) -> String {
  case value {
    option.Some(timestamp) -> format_timestamp(timestamp)
    option.None -> "None"
  }
}

fn format_timestamp(value: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}

fn optional_text(value: option.Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> "None"
  }
}

fn enabled_text(value: Bool) -> String {
  case value {
    True -> "Enabled"
    False -> "Disabled"
  }
}

fn schedule_status(editor: PeriodicJobEditor) -> String {
  case editor.metadata.last_enqueue_error {
    option.Some(_) -> "Last enqueue failed"
    option.None -> "No recent enqueue error"
  }
}

fn toggle_button_class(enabled: Bool) -> String {
  case enabled {
    True -> admin_ui.primary_button_class()
    False -> admin_ui.secondary_button_class()
  }
}

fn job_type_label(job_type: String) -> String {
  case job_type {
    "clean_api_log" -> "Clean API log"
    "clean_page_log" -> "Clean page log"
    "clean_pageview_log" -> "Clean pageview log"
    "clean_run_log" -> "Clean run log"
    "clean_job_log" -> "Clean job log"
    "clean_jobs" -> "Clean jobs"
    "clean_login_tokens" -> "Clean login tokens"
    "clean_user_actions" -> "Clean user actions"
    "aggregate_metrics" -> "Aggregate metrics"
    "delete_account" -> "Delete account"
    "send_email" -> "Send email"
    _ -> job_type
  }
}
