import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/run_log_dto
import glot_core/helpers/timestamp_helpers
import glot_core/language
import glot_core/pagination_model
import glot_core/route
import glot_core/run_log_model
import glot_frontend/admin/run_logs/list_message.{
  type Msg, ApplyFilters, LanguageFilterChanged, NextPageClicked,
  OutcomeFilterSelected, PreviousPageClicked, RequestIdFilterChanged,
  SessionIdFilterChanged, UserIdFilterChanged,
}
import glot_frontend/admin/run_logs/list_model.{type Model}
import glot_frontend/admin/ui/cursor_page as admin_cursor_page
import glot_frontend/admin/ui/filter as admin_filter
import glot_frontend/admin/ui/form as admin_form
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/admin/ui/pagination as admin_pagination
import glot_frontend/admin/ui/status as admin_status
import glot_frontend/admin/ui/table as admin_table
import glot_frontend/ui/duration_label
import glot_frontend/ui/string_helpers
import glot_web/route as web_route
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(current_page(model))

  admin_layout.page_with_panel_class(
    panel_class: "admin-job-logs-page",
    title: "Run logs",
    intro: "",
    actions: admin_pagination.cursor_pagination_actions(
      current_page(model),
      PreviousPageClicked,
      NextPageClicked,
    ),
    content: [
      admin_filter.filter_section(
        copy: filter_summary(model, rows),
        content: admin_filter.filter_surface([], [
          admin_filter.filter_field_grid(
            [attribute.class("admin-job-logs-page__field-grid")],
            [
              admin_form.text_input(
                label: "Request ID",
                help: request_id_help(model),
                value: model.request_id_filter,
                placeholder: "UUID",
                on_input: RequestIdFilterChanged,
              ),
              admin_form.text_input(
                label: "Session ID",
                help: session_id_help(model),
                value: model.session_id_filter,
                placeholder: "UUID",
                on_input: SessionIdFilterChanged,
              ),
              admin_form.text_input(
                label: "User ID",
                help: user_id_help(model),
                value: model.user_id_filter,
                placeholder: "UUID",
                on_input: UserIdFilterChanged,
              ),
              admin_form.select_input(
                label: "Language",
                value: model.language_filter,
                on_input: LanguageFilterChanged,
                options: language_options(),
                help: language_help(model),
              ),
            ],
          ),
          admin_filter.filter_row([], [
            admin_filter.filter_chip_group(
              title: "Outcome",
              copy: option.None,
              chips: [
                admin_filter.filter_chip(
                  [
                    event.on_click(OutcomeFilterSelected(run_log_dto.AllRunLogs)),
                  ],
                  "All",
                  model.outcome_filter == run_log_dto.AllRunLogs,
                ),
                admin_filter.filter_chip(
                  [
                    event.on_click(OutcomeFilterSelected(
                      run_log_dto.OnlySuccessfulRunLogs,
                    )),
                  ],
                  "Succeeded",
                  model.outcome_filter == run_log_dto.OnlySuccessfulRunLogs,
                ),
                admin_filter.filter_chip(
                  [
                    event.on_click(OutcomeFilterSelected(
                      run_log_dto.OnlyFailedRunLogs,
                    )),
                  ],
                  "Failed",
                  model.outcome_filter == run_log_dto.OnlyFailedRunLogs,
                ),
              ],
            ),
            admin_filter.filter_actions([], [
              html.button(
                [
                  attribute.class("admin-page__button"),
                  attribute.attribute("type", "button"),
                  event.on_click(ApplyFilters),
                ],
                [html.text("Apply")],
              ),
            ]),
          ]),
        ]),
      ),
      html.div([attribute.class("admin-page__group")], [
        html.div([attribute.class("admin-page__group-header")], [
          html.h3([attribute.class("admin-page__group-title")], [
            html.text("Results"),
          ]),
        ]),
        admin_status.loadable_status(model.page, "Loading run logs..."),
        logs_table(model, now),
      ]),
    ],
  )
}

fn logs_table(model: Model, now: Timestamp) -> Element(Msg) {
  admin_pagination.loadable_cursor_page_content(
    model.page,
    "Loading run logs...",
    "No run logs matched these filters.",
    fn(rows) {
      admin_table.table(log_columns(), {
        rows |> list.map(fn(log) { log_row(log, now) })
      })
    },
  )
}

fn current_page(
  model: Model,
) -> pagination_model.CursorPage(run_log_dto.RunLogResponse) {
  admin_cursor_page.current_page(model.page)
}

fn log_row(log: run_log_dto.RunLogResponse, now: Timestamp) -> Element(Msg) {
  admin_table.row([
    admin_table.linked_primary_cell(
      log_id_column(),
      [web_route.href(route.Admin(route.AdminRunLog(log.id)))],
      string_helpers.truncate_stem_middle(uuid.to_string(log.id), 18),
      option.None,
    ),
    admin_table.primary_cell(
      when_column(),
      timestamp_helpers.relative_label(log.created_at, now),
    ),
    admin_table.primary_cell(language_column(), language.name(log.language)),
    admin_table.cell(outcome_column(), [outcome_badge(log)]),
    admin_table.value_cell(
      duration_column(),
      optional_duration(log.duration_ns),
    ),
    admin_table.open_link_cell([
      web_route.href(route.Admin(route.AdminRunLog(log.id))),
    ]),
  ])
}

fn log_columns() -> List(admin_table.Column) {
  [
    log_id_column(),
    when_column(),
    language_column(),
    outcome_column(),
    duration_column(),
    open_column(),
  ]
}

fn log_id_column() -> admin_table.Column {
  admin_table.column("Log ID")
}

fn when_column() -> admin_table.Column {
  admin_table.column("Created at")
}

fn language_column() -> admin_table.Column {
  admin_table.column("Language")
}

fn outcome_column() -> admin_table.Column {
  admin_table.fit_column("Outcome")
}

fn duration_column() -> admin_table.Column {
  admin_table.fit_column("Duration")
}

fn open_column() -> admin_table.Column {
  admin_table.open_column()
}

fn filter_summary(
  model: Model,
  rows: List(run_log_dto.RunLogResponse),
) -> String {
  let count_text = int.to_string(list.length(rows)) <> " run logs shown."
  let outcome_text = case model.outcome_filter {
    run_log_dto.AllRunLogs -> " All outcomes included."
    run_log_dto.OnlySuccessfulRunLogs -> " Successful runs only."
    run_log_dto.OnlyFailedRunLogs -> " Failed runs only."
  }
  let request_text =
    optional_filter_text(
      "Request",
      model.applied_request_id_filter |> option.map(uuid.to_string),
    )
  let session_text =
    optional_filter_text(
      "Session",
      model.applied_session_id_filter |> option.map(uuid.to_string),
    )
  let user_text =
    optional_filter_text(
      "User",
      model.applied_user_id_filter |> option.map(uuid.to_string),
    )
  let language_text =
    optional_filter_text(
      "Language",
      model.applied_language_filter |> option.map(language.name),
    )

  count_text
  <> outcome_text
  <> request_text
  <> session_text
  <> user_text
  <> language_text
}

fn request_id_help(model: Model) -> String {
  case model.request_id_error {
    option.Some(message) -> message
    option.None ->
      case model.applied_request_id_filter {
        option.Some(request_id) -> "Filtering by " <> uuid.to_string(request_id)
        option.None -> "Leave blank to include all request IDs."
      }
  }
}

fn session_id_help(model: Model) -> String {
  case model.session_id_error {
    option.Some(message) -> message
    option.None ->
      case model.applied_session_id_filter {
        option.Some(session_id) -> "Filtering by " <> uuid.to_string(session_id)
        option.None -> "Leave blank to include all session IDs."
      }
  }
}

fn user_id_help(model: Model) -> String {
  case model.user_id_error {
    option.Some(message) -> message
    option.None ->
      case model.applied_user_id_filter {
        option.Some(user_id) -> "Filtering by " <> uuid.to_string(user_id)
        option.None -> "Leave blank to include all user IDs."
      }
  }
}

fn language_help(model: Model) -> String {
  case model.language_error {
    option.Some(message) -> message
    option.None ->
      case model.applied_language_filter {
        option.Some(selected) -> "Filtering by " <> language.name(selected)
        option.None -> "Leave on All languages to include every runtime."
      }
  }
}

fn language_options() -> List(#(String, String)) {
  [#("all", "All languages")]
  |> list.append(
    list.map(language.list(), fn(lang) {
      #(language.to_string(lang), language.name(lang))
    }),
  )
}

fn outcome_badge(log: run_log_dto.RunLogResponse) -> Element(Msg) {
  case log.outcome {
    run_log_model.RunSucceeded ->
      admin_layout.badge(outcome_text(log.outcome), admin_layout.SuccessTone)
    run_log_model.RunFailed ->
      admin_layout.badge(outcome_text(log.outcome), admin_layout.DangerTone)
  }
}

fn outcome_text(outcome: run_log_model.RunOutcome) -> String {
  case outcome {
    run_log_model.RunSucceeded -> "Succeeded"
    run_log_model.RunFailed -> "Failed"
  }
}

fn optional_duration(duration_ns: option.Option(Int)) -> String {
  case duration_ns {
    option.Some(value) -> duration_label.duration_in_ms_label(value)
    option.None -> "None"
  }
}

fn optional_filter_text(label: String, value: option.Option(String)) -> String {
  case value {
    option.Some(value) -> " " <> label <> ": " <> value <> "."
    option.None -> ""
  }
}
