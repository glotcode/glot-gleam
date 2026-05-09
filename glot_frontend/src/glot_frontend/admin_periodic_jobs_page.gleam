import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp
import glot_core/admin/periodic_job_dto
import glot_core/helpers/timestamp_helpers
import glot_core/route
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
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Periodic jobs"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "Review scheduler definitions, scan health quickly, and open a dedicated detail page when you need to edit one.",
              ),
            ]),
          ]),
        ]),
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
      ]),
    ]),
  ])
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
    summary_card(
      "Definitions",
      int.to_string(total_count),
      "Total configured jobs",
    ),
    summary_card(
      "Enabled",
      int.to_string(enabled_count),
      "Currently enqueueable",
    ),
    summary_card(
      "Disabled",
      int.to_string(disabled_count),
      "Paused definitions",
    ),
    summary_card(
      "Errors",
      int.to_string(failing_count),
      "Last enqueue attempt failed",
    ),
  ])
}

fn periodic_jobs_table(
  periodic_jobs: List(periodic_job_dto.PeriodicJobResponse),
  now: timestamp.Timestamp,
) -> Element(Msg) {
  html.div([attribute.class("jobs-table admin-periodic-jobs-page__table")], [
    html.div(
      [attribute.class("jobs-table__head admin-periodic-jobs-page__head")],
      [
        heading("Job type"),
        heading("State"),
        heading("Cadence"),
        heading("Next run"),
        heading("Last enqueued"),
        heading("Action"),
      ],
    ),
    html.div(
      [attribute.class("jobs-table__body")],
      list.map(periodic_jobs, fn(periodic_job) {
        periodic_job_row(periodic_job, now)
      }),
    ),
  ])
}

fn periodic_job_row(
  periodic_job: periodic_job_dto.PeriodicJobResponse,
  now: timestamp.Timestamp,
) -> Element(Msg) {
  html.div([attribute.class("jobs-table__row admin-periodic-jobs-page__row")], [
    cell("Job type", [
      html.span([attribute.class("jobs-table__primary")], [
        html.text(job_type_label(periodic_job.job_type)),
      ]),
    ]),
    cell("State", [
      status_chip(periodic_job),
    ]),
    cell("Cadence", [
      html.text(int.to_string(periodic_job.interval_seconds) <> "s"),
    ]),
    cell("Next run", [
      html.text(timestamp_helpers.relative_label(periodic_job.next_run_at, now)),
    ]),
    cell("Last enqueued", [
      html.text(optional_relative_timestamp(periodic_job.last_enqueued_at, now)),
    ]),
    cell("Action", [
      html.a(
        [
          attribute.class("admin-page__button admin-page__button--secondary"),
          route.href(route.AdminPeriodicJob(periodic_job.id)),
        ],
        [html.text("Open")],
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

fn heading(label: String) -> Element(Msg) {
  html.div([attribute.class("jobs-table__heading")], [html.text(label)])
}

fn cell(label: String, children: List(Element(Msg))) -> Element(Msg) {
  html.div([], [
    html.span([attribute.class("jobs-table__cell-label")], [html.text(label)]),
    html.div([attribute.class("jobs-table__primary-cell")], children),
  ])
}

fn status_chip(
  periodic_job: periodic_job_dto.PeriodicJobResponse,
) -> Element(Msg) {
  let #(label, class_name) = case
    periodic_job.enabled,
    periodic_job.last_enqueue_error
  {
    False, _ -> #("Disabled", "jobs-table__badge")
    True, option.Some(_) -> #(
      "Error",
      "jobs-table__badge jobs-table__badge--failed",
    )
    True, option.None -> #(
      "Enabled",
      "jobs-table__badge jobs-table__badge--done",
    )
  }

  html.span([attribute.class(class_name)], [html.text(label)])
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
