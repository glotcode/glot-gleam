import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/job_dto
import glot_core/helpers/timestamp_helpers
import glot_core/job/job_model
import glot_core/pagination_model
import glot_core/route
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/string_helpers
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

const page_limit = 25

pub type Model {
  Model(
    page: pagination_model.CursorPage(job_dto.JobResponse),
    summary: job_dto.JobsSummary,
    status: Status,
    status_filter: job_dto.StatusFilter,
    job_type_filter: option.Option(String),
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type Msg {
  JobsLoaded(api.ApiResponse(job_dto.ListJobsResponse))
  StatusFilterSelected(job_dto.StatusFilter)
  JobTypeFilterSelected(String)
  NextPageClicked
  PreviousPageClicked
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      page: pagination_model.InitialCursorPage(
        items: [],
        next_cursor: option.None,
      ),
      summary: job_dto.empty_summary(),
      status: NotLoaded,
      status_filter: job_dto.AllStatuses,
      job_type_filter: option.None,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> load_initial(model)
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    JobsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            page: response.page,
            summary: response.summary,
            status: Ready,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load jobs.")),
          effect.none(),
        )
      }

    StatusFilterSelected(filter) ->
      case filter == model.status_filter {
        True -> #(model, effect.none())
        False -> load_initial(Model(..model, status_filter: filter))
      }

    JobTypeFilterSelected(filter) -> {
      let next_filter = job_type_filter_value(filter)

      case next_filter == model.job_type_filter {
        True -> #(model, effect.none())
        False -> load_initial(Model(..model, job_type_filter: next_filter))
      }
    }

    NextPageClicked ->
      case pagination_model.next_cursor(model.page) {
        option.Some(cursor) ->
          load_page(
            Model(..model, status: Loading),
            pagination_model.AfterPage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case pagination_model.previous_cursor(model.page) {
        option.Some(cursor) ->
          load_page(
            Model(..model, status: Loading),
            pagination_model.BeforePage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let items = pagination_model.items(model.page)

  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-jobs-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Jobs overview"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "Review queue health, recent job executions, and filtered slices of the retained jobs history.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            pagination_button(
              "Previous",
              PreviousPageClicked,
              can_go_previous(model),
            ),
            pagination_button("Next", NextPageClicked, can_go_next(model)),
          ]),
        ]),
        html.div([attribute.class("admin-jobs-page__summary-grid")], {
          summary_stats(model.summary)
          |> list.map(summary_card)
        }),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Filters"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(filtered_status_text(model, items)),
            ]),
          ]),
          html.div(
            [attribute.class("admin-page__policy admin-jobs-page__filters")],
            [
              filter_group(title: "Status", chips: [
                filter_chip(
                  "All",
                  model.status_filter == job_dto.AllStatuses,
                  StatusFilterSelected(job_dto.AllStatuses),
                ),
                filter_chip(
                  "Pending",
                  model.status_filter == job_dto.PendingStatus,
                  StatusFilterSelected(job_dto.PendingStatus),
                ),
                filter_chip(
                  "Running",
                  model.status_filter == job_dto.RunningStatus,
                  StatusFilterSelected(job_dto.RunningStatus),
                ),
                filter_chip(
                  "Failed",
                  model.status_filter == job_dto.FailedStatus,
                  StatusFilterSelected(job_dto.FailedStatus),
                ),
                filter_chip(
                  "Done",
                  model.status_filter == job_dto.DoneStatus,
                  StatusFilterSelected(job_dto.DoneStatus),
                ),
              ]),
              select_filter_group(
                title: "Job type",
                selected_value: selected_job_type_value(model.job_type_filter),
                on_input: JobTypeFilterSelected,
              ),
            ],
          ),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Queue"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Rows are paginated from the backend and use the current filter set, so this view can scale with retained job history.",
              ),
            ]),
          ]),
          status_view(model),
          jobs_table(model, now),
        ]),
      ]),
    ]),
  ])
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  let reset_page =
    pagination_model.InitialCursorPage(items: [], next_cursor: option.None)

  load_page(
    Model(..model, page: reset_page, status: Loading),
    pagination_model.InitialPage(limit: page_limit),
  )
}

fn load_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, Effect(Msg)) {
  #(
    model,
    api.get_admin_jobs(
      job_dto.ListJobsRequest(
        pagination: pagination,
        status_filter: model.status_filter,
        job_type_filter: model.job_type_filter,
        periodic_job_id: option.None,
      ),
      JobsLoaded,
    ),
  )
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [
        html.text(""),
      ])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading jobs..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn jobs_table(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.page)

  case rows, model.status {
    [], Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading jobs..."),
      ])

    [], _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No jobs match the current filters."),
      ])

    _, _ ->
      admin_table.table(job_columns(), {
        rows |> list.map(fn(job) { job_row(job, now) })
      })
  }
}

fn summary_stats(summary: job_dto.JobsSummary) -> List(SummaryStat) {
  [
    SummaryStat("Pending", summary.pending_count, NeutralSummary),
    SummaryStat("Running", summary.running_count, WarningSummary),
    SummaryStat("Failed", summary.failed_count, DangerSummary),
    SummaryStat("Overdue", summary.overdue_count, DangerSummary),
    SummaryStat("Completed", summary.done_count, SuccessSummary),
  ]
}

type SummaryStat {
  SummaryStat(label: String, value: Int, tone: SummaryTone)
}

type SummaryTone {
  NeutralSummary
  WarningSummary
  DangerSummary
  SuccessSummary
}

fn filtered_status_text(
  model: Model,
  items: List(job_dto.JobResponse),
) -> String {
  int.to_string(list.length(items))
  <> " of "
  <> int.to_string(model.summary.total_count)
  <> " jobs shown. "
  <> status_filter_copy(model.status_filter)
  <> " "
  <> job_type_filter_copy(model.job_type_filter)
}

fn summary_card(stat: SummaryStat) -> Element(Msg) {
  html.article(
    [attribute.class("admin-page__policy admin-jobs-page__summary-card")],
    [
      html.span([attribute.class("admin-jobs-page__summary-label")], [
        html.text(stat.label),
      ]),
      html.div([attribute.class("admin-jobs-page__summary-value-row")], [
        html.strong([attribute.class("admin-jobs-page__summary-value")], [
          html.text(int.to_string(stat.value)),
        ]),
        html.span([attribute.class(summary_tone_class(stat.tone))], [
          html.text(summary_tone_text(stat.tone)),
        ]),
      ]),
    ],
  )
}

fn filter_group(
  title title: String,
  chips chips: List(Element(Msg)),
) -> Element(Msg) {
  html.div([attribute.class("admin-jobs-page__filter-group")], [
    html.span([attribute.class("admin-jobs-page__filter-title")], [
      html.text(title),
    ]),
    html.div([attribute.class("admin-page__policy-actions")], chips),
  ])
}

fn select_filter_group(
  title title: String,
  selected_value selected_value: String,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-jobs-page__filter-group")], [
    html.span([attribute.class("admin-jobs-page__filter-title")], [
      html.text(title),
    ]),
    html.select(
      [
        attribute.class("admin-page__input"),
        attribute.value(selected_value),
        event.on_input(on_input),
      ],
      job_type_options(selected_value),
    ),
  ])
}

fn filter_chip(label: String, selected: Bool, msg: Msg) -> Element(Msg) {
  let class_name = case selected {
    True -> "admin-page__chip admin-page__chip--selected"
    False -> "admin-page__chip"
  }

  html.button(
    [
      attribute.class(class_name),
      attribute.attribute("type", "button"),
      attribute.attribute("aria-pressed", bool_attribute(selected)),
      event.on_click(msg),
    ],
    [html.text(label)],
  )
}

fn pagination_button(label: String, msg: Msg, enabled: Bool) -> Element(Msg) {
  admin_ui.secondary_button(
    [
      attribute.attribute("type", "button"),
      attribute.disabled(!enabled),
      event.on_click(msg),
    ],
    label,
  )
}

fn job_row(job: job_dto.JobResponse, now: Timestamp) -> Element(Msg) {
  admin_table.row([
    admin_table.cell(job_column(), [
      admin_table.stack([
        html.span([attribute.class("admin-table__value--primary")], [
          html.text(job.job_type),
        ]),
      ]),
    ]),
    admin_table.cell(status_column(), [
      admin_table.stack([
        status_badge(job),
      ]),
    ]),
    admin_table.cell(schedule_column(), [
      admin_table.stack([
        html.span([attribute.class("admin-table__value--primary")], [
          html.text(timestamp_helpers.relative_label(job.run_at, now)),
        ]),
      ]),
    ]),
    admin_table.cell(attempts_column(), [
      admin_table.stack([
        html.span([attribute.class("admin-table__value--primary")], [
          html.text(
            int.to_string(job.attempts)
            <> " / "
            <> int.to_string(job.max_attempts),
          ),
        ]),
      ]),
    ]),
    admin_table.cell(notes_column(), [admin_table.value(note_text(job))]),
    admin_table.cell(action_column(), [
      admin_ui.secondary_link([route.href(route.AdminJob(job.id))], "Open"),
    ]),
  ])
}

fn job_columns() -> List(admin_table.Column) {
  [
    job_column(),
    status_column(),
    schedule_column(),
    attempts_column(),
    notes_column(),
    action_column(),
  ]
}

fn job_column() -> admin_table.Column {
  admin_table.column("Job")
}

fn status_column() -> admin_table.Column {
  admin_table.fit_column("Status")
}

fn schedule_column() -> admin_table.Column {
  admin_table.column("Run at")
}

fn attempts_column() -> admin_table.Column {
  admin_table.fit_column("Attempts")
}

fn notes_column() -> admin_table.Column {
  admin_table.column("Notes")
}

fn action_column() -> admin_table.Column {
  admin_table.action_column("Action")
}

fn note_text(job: job_dto.JobResponse) -> String {
  case job.last_error {
    option.Some(last_error) -> string_helpers.truncate_end(last_error, 50)
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

fn summary_tone_class(tone: SummaryTone) -> String {
  case tone {
    NeutralSummary -> "admin-jobs-page__summary-tone"
    WarningSummary ->
      "admin-jobs-page__summary-tone admin-jobs-page__summary-tone--warning"
    DangerSummary ->
      "admin-jobs-page__summary-tone admin-jobs-page__summary-tone--danger"
    SuccessSummary ->
      "admin-jobs-page__summary-tone admin-jobs-page__summary-tone--success"
  }
}

fn summary_tone_text(tone: SummaryTone) -> String {
  case tone {
    NeutralSummary -> "Queue"
    WarningSummary -> "Active"
    DangerSummary -> "Needs review"
    SuccessSummary -> "Complete"
  }
}

fn status_badge(job: job_dto.JobResponse) -> Element(Msg) {
  case job.status, job.overdue {
    "failed", _ -> admin_ui.badge(status_text(job), admin_ui.DangerTone)
    "running", _ -> admin_ui.badge(status_text(job), admin_ui.WarningTone)
    "pending", True -> admin_ui.badge(status_text(job), admin_ui.DangerTone)
    "pending", False -> admin_ui.badge(status_text(job), admin_ui.InfoTone)
    "done", _ -> admin_ui.badge(status_text(job), admin_ui.SuccessTone)
    _, _ -> admin_ui.badge(status_text(job), admin_ui.NeutralTone)
  }
}

fn status_text(job: job_dto.JobResponse) -> String {
  case job.status, job.overdue {
    "pending", True -> "Pending • overdue"
    "pending", False -> "Pending"
    "running", _ -> "Running"
    "failed", _ -> "Failed"
    "done", _ -> "Done"
    value, _ -> value
  }
}

fn status_filter_copy(filter: job_dto.StatusFilter) -> String {
  case filter {
    job_dto.AllStatuses -> "Showing every status."
    job_dto.PendingStatus -> "Focused on jobs waiting to be claimed."
    job_dto.RunningStatus -> "Focused on jobs currently being processed."
    job_dto.FailedStatus -> "Focused on jobs that need operator review."
    job_dto.DoneStatus -> "Focused on completed executions."
  }
}

fn job_type_filter_copy(filter: option.Option(String)) -> String {
  case filter {
    option.None -> "All job types are included."
    option.Some(job_type) -> "Focused on " <> job_type <> "."
  }
}

fn can_go_previous(model: Model) -> Bool {
  case pagination_model.previous_cursor(model.page) {
    option.Some(_) -> model.status != Loading
    option.None -> False
  }
}

fn can_go_next(model: Model) -> Bool {
  case pagination_model.next_cursor(model.page) {
    option.Some(_) -> model.status != Loading
    option.None -> False
  }
}

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}

fn selected_job_type_value(filter: option.Option(String)) -> String {
  case filter {
    option.Some(job_type) -> job_type
    option.None -> "all"
  }
}

fn job_type_filter_value(value: String) -> option.Option(String) {
  case value {
    "all" -> option.None
    job_type -> option.Some(job_type)
  }
}

fn job_type_options(selected_value: String) -> List(Element(Msg)) {
  [job_type_option("all", "All jobs", selected_value)]
  |> list.append(
    list.map(job_type_values(), fn(job_type) {
      job_type_option(job_type, job_type, selected_value)
    }),
  )
}

fn job_type_option(
  value: String,
  label: String,
  selected_value: String,
) -> Element(Msg) {
  html.option(
    [
      attribute.value(value),
      attribute.selected(value == selected_value),
    ],
    label,
  )
}

fn job_type_values() -> List(String) {
  [
    job_model.SendEmailJob,
    job_model.DeleteAccountJob,
    job_model.CleanApiLogJob,
    job_model.CleanPageLogJob,
    job_model.CleanPageviewLogJob,
    job_model.CleanRunLogJob,
    job_model.CleanJobLogJob,
    job_model.CleanJobsJob,
    job_model.CleanLoginTokensJob,
    job_model.CleanUserActionsJob,
    job_model.AggregateMetricsJob,
  ]
  |> list.map(job_model.job_type_to_string)
}
