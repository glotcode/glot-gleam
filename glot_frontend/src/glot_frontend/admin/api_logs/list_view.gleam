import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/api_log_dto
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/admin/api_logs/list_message.{
  type Msg, ApplyFilters, ErrorFilterSelected, NextPageClicked,
  PreviousPageClicked, RequestIdFilterChanged,
}
import glot_frontend/admin/api_logs/list_model.{type Model}
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
    panel_class: "admin-request-logs-page",
    title: "API logs",
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
          admin_filter.filter_field_grid([], [
            admin_form.text_input(
              label: "Request ID",
              help: request_id_help(model),
              value: model.request_id_filter,
              placeholder: "UUID",
              on_input: RequestIdFilterChanged,
            ),
          ]),
          admin_filter.filter_row([], [
            admin_filter.filter_chip_group(
              title: "Error",
              copy: option.None,
              chips: [
                admin_filter.filter_chip(
                  [event.on_click(ErrorFilterSelected(api_log_dto.AllApiLogs))],
                  "All",
                  model.error_filter == api_log_dto.AllApiLogs,
                ),
                admin_filter.filter_chip(
                  [
                    event.on_click(ErrorFilterSelected(
                      api_log_dto.OnlyApiLogsWithErrors,
                    )),
                  ],
                  "Errors only",
                  model.error_filter == api_log_dto.OnlyApiLogsWithErrors,
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
        admin_status.loadable_status(model.page, "Loading API logs..."),
        logs_table(model, now),
      ]),
    ],
  )
}

fn logs_table(model: Model, now: Timestamp) -> Element(Msg) {
  admin_pagination.loadable_cursor_page_content(
    model.page,
    "Loading API logs...",
    "No API logs matched these filters.",
    fn(rows) {
      admin_table.table(log_columns(), {
        rows |> list.map(fn(log) { log_row(log, now) })
      })
    },
  )
}

fn current_page(
  model: Model,
) -> pagination_model.CursorPage(api_log_dto.ApiLogSummaryResponse) {
  admin_cursor_page.current_page(model.page)
}

fn log_row(
  log: api_log_dto.ApiLogSummaryResponse,
  now: Timestamp,
) -> Element(Msg) {
  admin_table.row([
    admin_table.linked_primary_cell(
      log_id_column(),
      [web_route.href(route.Admin(route.AdminApiLog(log.id)))],
      string_helpers.truncate_stem_middle(uuid.to_string(log.id), 18),
      option.None,
    ),
    admin_table.primary_cell(
      when_column(),
      timestamp_helpers.relative_label(log.created_at, now),
    ),
    admin_table.value_cell(action_column(), log.action),
    admin_table.value_cell(
      duration_column(),
      duration_label.duration_in_ms_label(log.duration_ns),
    ),
    admin_table.cell(error_column(), [admin_status.error_badge(log.has_error)]),
    admin_table.open_link_cell([
      web_route.href(route.Admin(route.AdminApiLog(log.id))),
    ]),
  ])
}

fn log_columns() -> List(admin_table.Column) {
  [
    log_id_column(),
    when_column(),
    action_column(),
    duration_column(),
    error_column(),
    open_column(),
  ]
}

fn log_id_column() -> admin_table.Column {
  admin_table.column("Log ID")
}

fn when_column() -> admin_table.Column {
  admin_table.column("Created at")
}

fn action_column() -> admin_table.Column {
  admin_table.column("Action")
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

fn filter_summary(
  model: Model,
  rows: List(api_log_dto.ApiLogSummaryResponse),
) -> String {
  let base =
    int.to_string(list.length(rows))
    <> " API logs shown. "
    <> case model.error_filter {
      api_log_dto.AllApiLogs -> "All logs included."
      api_log_dto.OnlyApiLogsWithErrors -> "Errors only."
    }

  case model.applied_request_id_filter {
    option.Some(request_id) ->
      base <> " Request filter: " <> uuid.to_string(request_id)
    option.None -> base
  }
}

fn request_id_help(model: Model) -> String {
  case model.request_id_error {
    option.Some(message) -> message
    option.None ->
      case model.applied_request_id_filter {
        option.Some(request_id) -> "Filtering by " <> uuid.to_string(request_id)
        option.None -> "Leave blank to include all API request IDs."
      }
  }
}
