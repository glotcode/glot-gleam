import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_core/admin/periodic_job_dto
import glot_core/helpers/timestamp_helpers
import glot_core/route
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(
    periodic_jobs: List(periodic_job_dto.PeriodicJobResponse),
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
  PeriodicJobsLoaded(api.ApiResponse(periodic_job_dto.ListPeriodicJobsResponse))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model(periodic_jobs: [], status: NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      api.get_admin_periodic_jobs(PeriodicJobsLoaded),
    )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    PeriodicJobsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(periodic_jobs: response.periodic_jobs, status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load periodic jobs.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model, now: timestamp.Timestamp) -> Element(Msg) {
  admin_ui.page(
    title: "Periodic jobs",
    intro:
      "Review scheduler definitions, scan health quickly, and open a dedicated detail page when you need to edit one.",
    content: [
      status_banner(model.status),
      summary_view(model),
      html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Definitions"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "This index stays compact on purpose. Open a periodic job to inspect its payload, timestamps, and editable scheduler settings.",
              ),
            ]),
          ]),
          case model.periodic_jobs {
            [] ->
              html.div([attribute.class("admin-page__empty")], [
                html.text("No periodic jobs were returned."),
              ])
            _ -> periodic_jobs_table(model.periodic_jobs, now)
          },
      ]),
    ],
  )
}

fn summary_view(model: Model) -> Element(Msg) {
  let total_count = list.length(model.periodic_jobs)
  let enabled_count =
    model.periodic_jobs
    |> list.filter(fn(job) { job.enabled })
    |> list.length
  let disabled_count = total_count - enabled_count
  let failing_count =
    model.periodic_jobs
    |> list.filter(fn(job) {
      case job.last_enqueue_error {
        option.Some(_) -> True
        option.None -> False
      }
    })
    |> list.length

  html.div([attribute.class("admin-periodic-jobs-page__summary-grid")], [
    admin_ui.summary_card_with_class(
      "admin-page__policy admin-periodic-jobs-page__summary-card",
      "Definitions",
      int.to_string(total_count),
    ),
    admin_ui.summary_card_with_class(
      "admin-page__policy admin-periodic-jobs-page__summary-card",
      "Enabled",
      int.to_string(enabled_count),
    ),
    admin_ui.summary_card_with_class(
      "admin-page__policy admin-periodic-jobs-page__summary-card",
      "Disabled",
      int.to_string(disabled_count),
    ),
    admin_ui.summary_card_with_class(
      "admin-page__policy admin-periodic-jobs-page__summary-card",
      "Errors",
      int.to_string(failing_count),
    ),
  ])
}

fn periodic_jobs_table(
  periodic_jobs: List(periodic_job_dto.PeriodicJobResponse),
  now: timestamp.Timestamp,
) -> Element(Msg) {
  admin_table.table(
    periodic_job_columns(),
    list.map(periodic_jobs, fn(periodic_job) {
      periodic_job_row(periodic_job, now)
    }),
  )
}

fn periodic_job_row(
  periodic_job: periodic_job_dto.PeriodicJobResponse,
  now: timestamp.Timestamp,
) -> Element(Msg) {
  admin_table.row([
    admin_table.cell(job_type_column(), [
      html.span([attribute.class("admin-table__value--primary")], [
        html.text(job_type_label(periodic_job.job_type)),
      ]),
    ]),
    admin_table.cell(state_column(), [
      status_chip(periodic_job),
    ]),
    admin_table.cell(cadence_column(), [
      html.text(int.to_string(periodic_job.interval_seconds) <> "s"),
    ]),
    admin_table.cell(next_run_column(), [
      admin_table.primary_value(timestamp_helpers.relative_label(
        periodic_job.next_run_at,
        now,
      )),
    ]),
    admin_table.cell(last_enqueued_column(), [
      admin_table.value(optional_relative_timestamp(
        periodic_job.last_enqueued_at,
        now,
      )),
    ]),
    admin_table.cell(action_column(), [
      admin_ui.secondary_link(
        [route.href(route.AdminPeriodicJob(periodic_job.id))],
        "Open",
      ),
    ]),
  ])
}

fn status_banner(status: Status) -> Element(Msg) {
  case status {
    NotLoaded | Ready -> html.div([], [])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading periodic jobs..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn periodic_job_columns() -> List(admin_table.Column) {
  [
    job_type_column(),
    state_column(),
    cadence_column(),
    next_run_column(),
    last_enqueued_column(),
    action_column(),
  ]
}

fn job_type_column() -> admin_table.Column {
  admin_table.column("Job type")
}

fn state_column() -> admin_table.Column {
  admin_table.fit_column("State")
}

fn cadence_column() -> admin_table.Column {
  admin_table.fit_column("Cadence")
}

fn next_run_column() -> admin_table.Column {
  admin_table.column("Next run")
}

fn last_enqueued_column() -> admin_table.Column {
  admin_table.column("Last enqueued")
}

fn action_column() -> admin_table.Column {
  admin_table.action_column("Action")
}

fn status_chip(
  periodic_job: periodic_job_dto.PeriodicJobResponse,
) -> Element(Msg) {
  case periodic_job.enabled, periodic_job.last_enqueue_error {
    False, _ -> admin_ui.badge("Disabled", admin_ui.NeutralTone)
    True, option.Some(_) -> admin_ui.badge("Error", admin_ui.DangerTone)
    True, option.None -> admin_ui.badge("Enabled", admin_ui.SuccessTone)
  }
}

fn optional_relative_timestamp(
  value: option.Option(timestamp.Timestamp),
  now: timestamp.Timestamp,
) -> String {
  case value {
    option.Some(timestamp) -> timestamp_helpers.relative_label(timestamp, now)
    option.None -> "Never"
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
