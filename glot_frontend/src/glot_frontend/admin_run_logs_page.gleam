import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/run_log_dto
import glot_core/helpers/timestamp_helpers
import glot_core/language
import glot_core/pagination_model
import glot_core/route
import glot_core/run_log_model
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/duration_label
import glot_frontend/loadable
import glot_frontend/string_helpers
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

const page_limit = 25

pub type Model {
  Model(
    page: loadable.Loadable(pagination_model.CursorPage(run_log_dto.RunLogResponse)),
    outcome_filter: run_log_dto.RunLogOutcomeFilter,
    request_id_filter: String,
    session_id_filter: String,
    user_id_filter: String,
    language_filter: String,
    applied_request_id_filter: option.Option(uuid.Uuid),
    applied_session_id_filter: option.Option(uuid.Uuid),
    applied_user_id_filter: option.Option(uuid.Uuid),
    applied_language_filter: option.Option(language.Language),
    request_id_error: option.Option(String),
    session_id_error: option.Option(String),
    user_id_error: option.Option(String),
    language_error: option.Option(String),
  )
}

pub type Msg {
  LogsLoaded(api.ApiResponse(run_log_dto.ListRunLogsResponse))
  OutcomeFilterSelected(run_log_dto.RunLogOutcomeFilter)
  RequestIdFilterChanged(String)
  SessionIdFilterChanged(String)
  UserIdFilterChanged(String)
  LanguageFilterChanged(String)
  ApplyFilters
  NextPageClicked
  PreviousPageClicked
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      page: loadable.NotLoaded,
      outcome_filter: run_log_dto.AllRunLogs,
      request_id_filter: "",
      session_id_filter: "",
      user_id_filter: "",
      language_filter: "all",
      applied_request_id_filter: option.None,
      applied_session_id_filter: option.None,
      applied_user_id_filter: option.None,
      applied_language_filter: option.None,
      request_id_error: option.None,
      session_id_error: option.None,
      user_id_error: option.None,
      language_error: option.None,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.page {
    loadable.NotLoaded -> load_initial(model)
    loadable.Loading | loadable.Loaded(_) | loadable.LoadError(_) ->
      #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LogsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, page: loadable.Loaded(response.page)),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, page: loadable.LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, page: loadable.LoadError("Could not load run logs.")),
          effect.none(),
        )
      }

    OutcomeFilterSelected(filter) ->
      case filter == model.outcome_filter {
        True -> #(model, effect.none())
        False ->
          load_initial(
            Model(
              ..model,
              outcome_filter: filter,
              request_id_error: option.None,
              session_id_error: option.None,
              user_id_error: option.None,
              language_error: option.None,
            ),
          )
      }

    RequestIdFilterChanged(value) -> #(
      Model(..model, request_id_filter: value, request_id_error: option.None),
      effect.none(),
    )

    SessionIdFilterChanged(value) -> #(
      Model(..model, session_id_filter: value, session_id_error: option.None),
      effect.none(),
    )

    UserIdFilterChanged(value) -> #(
      Model(..model, user_id_filter: value, user_id_error: option.None),
      effect.none(),
    )

    LanguageFilterChanged(value) -> #(
      Model(..model, language_filter: value, language_error: option.None),
      effect.none(),
    )

    ApplyFilters ->
      case parse_uuid_filter(model.request_id_filter, "Request ID") {
        Ok(request_id) ->
          case parse_uuid_filter(model.session_id_filter, "Session ID") {
            Ok(session_id) ->
              case parse_uuid_filter(model.user_id_filter, "User ID") {
                Ok(user_id) ->
                  case parse_language_filter(model.language_filter) {
                    Ok(language_filter) ->
                      load_initial(
                        Model(
                          ..model,
                          applied_request_id_filter: request_id,
                          applied_session_id_filter: session_id,
                          applied_user_id_filter: user_id,
                          applied_language_filter: language_filter,
                          request_id_error: option.None,
                          session_id_error: option.None,
                          user_id_error: option.None,
                          language_error: option.None,
                        ),
                      )
                    Error(message) -> #(
                      Model(
                        ..model,
                        page: loadable.LoadError(message),
                        language_error: option.Some(message),
                      ),
                      effect.none(),
                    )
                  }
                Error(message) -> #(
                  Model(
                    ..model,
                    page: loadable.LoadError(message),
                    user_id_error: option.Some(message),
                  ),
                  effect.none(),
                )
              }
            Error(message) -> #(
              Model(
                ..model,
                page: loadable.LoadError(message),
                session_id_error: option.Some(message),
              ),
              effect.none(),
            )
          }
        Error(message) -> #(
          Model(
            ..model,
            page: loadable.LoadError(message),
            request_id_error: option.Some(message),
          ),
          effect.none(),
        )
      }

    NextPageClicked ->
      case pagination_model.next_cursor(current_page(model)) {
        option.Some(cursor) ->
          load_page(
            Model(..model, page: loadable.Loading),
            pagination_model.AfterPage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case pagination_model.previous_cursor(current_page(model)) {
        option.Some(cursor) ->
          load_page(
            Model(..model, page: loadable.Loading),
            pagination_model.BeforePage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(current_page(model))

  admin_ui.page_with_panel_class(
    panel_class: "admin-job-logs-page",
    title: "Run logs",
    intro: "",
    actions: [
      pagination_button("Previous", PreviousPageClicked, can_go_previous(model)),
      pagination_button("Next", NextPageClicked, can_go_next(model)),
    ],
    content: [
      html.div([attribute.class("admin-page__group")], [
            html.div([attribute.class("admin-page__group-header")], [
              html.h3([attribute.class("admin-page__group-title")], [
                html.text("Filters"),
              ]),
              html.p([attribute.class("admin-page__group-copy")], [
                html.text(filter_summary(model, rows)),
              ]),
            ]),
            html.div(
              [
                attribute.class(
                  "admin-page__policy admin-job-logs-page__filters",
                ),
              ],
              [
                html.div(
                  [
                    attribute.class(
                      "admin-page__field-grid admin-job-logs-page__field-grid",
                    ),
                  ],
                  [
                    text_input(
                      label: "Request ID",
                      help: request_id_help(model),
                      value: model.request_id_filter,
                      on_input: RequestIdFilterChanged,
                    ),
                    text_input(
                      label: "Session ID",
                      help: session_id_help(model),
                      value: model.session_id_filter,
                      on_input: SessionIdFilterChanged,
                    ),
                    text_input(
                      label: "User ID",
                      help: user_id_help(model),
                      value: model.user_id_filter,
                      on_input: UserIdFilterChanged,
                    ),
                    select_input(
                      label: "Language",
                      value: model.language_filter,
                      on_input: LanguageFilterChanged,
                      options: language_options(),
                      help: language_help(model),
                    ),
                  ],
                ),
                html.div([attribute.class("admin-job-logs-page__filter-row")], [
                  filter_group(title: "Outcome", chips: [
                    filter_chip(
                      "All",
                      model.outcome_filter == run_log_dto.AllRunLogs,
                      OutcomeFilterSelected(run_log_dto.AllRunLogs),
                    ),
                    filter_chip(
                      "Succeeded",
                      model.outcome_filter == run_log_dto.OnlySuccessfulRunLogs,
                      OutcomeFilterSelected(run_log_dto.OnlySuccessfulRunLogs),
                    ),
                    filter_chip(
                      "Failed",
                      model.outcome_filter == run_log_dto.OnlyFailedRunLogs,
                      OutcomeFilterSelected(run_log_dto.OnlyFailedRunLogs),
                    ),
                  ]),
                  html.div([attribute.class("admin-job-logs-page__apply")], [
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
              ],
            ),
      ]),
      html.div([attribute.class("admin-page__group")], [
            html.div([attribute.class("admin-page__group-header")], [
              html.h3([attribute.class("admin-page__group-title")], [
                html.text("Results"),
              ]),
            ]),
            status_view(model),
            logs_table(model, now),
      ]),
    ],
  )
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  load_page(
    Model(..model, page: loadable.Loading),
    pagination_model.InitialPage(limit: page_limit),
  )
}

fn load_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, Effect(Msg)) {
  #(
    model,
    api.get_admin_run_logs(
      run_log_dto.ListRunLogsRequest(
        pagination: pagination,
        request_id: model.applied_request_id_filter,
        session_id: model.applied_session_id_filter,
        user_id: model.applied_user_id_filter,
        language: model.applied_language_filter,
        outcome_filter: model.outcome_filter,
      ),
      LogsLoaded,
    ),
  )
}

fn status_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.page,
    admin_ui.status(""),
    admin_ui.status("Loading run logs..."),
    fn(_) { admin_ui.status("") },
    admin_ui.error_status,
  )
}

fn logs_table(model: Model, now: Timestamp) -> Element(Msg) {
  loadable.fold(
    model.page,
    admin_ui.empty_state("No run logs matched these filters."),
    admin_ui.empty_state("Loading run logs..."),
    fn(page) {
      case pagination_model.items(page) {
        [] -> admin_ui.empty_state("No run logs matched these filters.")
        rows ->
          admin_table.table(log_columns(), {
            rows |> list.map(fn(log) { log_row(log, now) })
          })
      }
    },
    fn(_) { admin_ui.empty_state("No run logs matched these filters.") },
  )
}

fn current_page(
  model: Model,
) -> pagination_model.CursorPage(run_log_dto.RunLogResponse) {
  case model.page {
    loadable.Loaded(page) -> page
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) -> empty_page()
  }
}

fn filter_group(
  title title: String,
  chips chips: List(Element(Msg)),
) -> Element(Msg) {
  html.div([attribute.class("admin-job-logs-page__filter-group")], [
    html.span([attribute.class("admin-jobs-page__filter-title")], [
      html.text(title),
    ]),
    html.div([attribute.class("admin-page__actions")], chips),
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

fn text_input(
  label label: String,
  help help: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.input([
      attribute.type_("text"),
      attribute.class("admin-page__input"),
      attribute.value(value),
      attribute.attribute("placeholder", "UUID"),
      event.on_input(on_input),
    ]),
    html.span([attribute.class("admin-page__field-help")], [html.text(help)]),
  ])
}

fn select_input(
  label label: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
  options options: List(#(String, String)),
  help help: String,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.select(
      [
        attribute.class("admin-page__input"),
        attribute.value(value),
        event.on_input(on_input),
      ],
      list.map(options, fn(option_item) {
        let #(option_value, option_label) = option_item
        html.option(
          [
            attribute.value(option_value),
            attribute.selected(option_value == value),
          ],
          option_label,
        )
      }),
    ),
    html.span([attribute.class("admin-page__field-help")], [html.text(help)]),
  ])
}

fn log_row(log: run_log_dto.RunLogResponse, now: Timestamp) -> Element(Msg) {
  admin_table.row([
    admin_table.cell(log_id_column(), [
      admin_table.stack([
        html.a(
          [
            attribute.class(
              "admin-table__value admin-table__value--primary admin-job-logs-page__link",
            ),
            route.href(route.AdminRunLog(log.id)),
          ],
          [
            html.text(string_helpers.truncate_stem_middle(
              uuid.to_string(log.id),
              18,
            )),
          ],
        ),
      ]),
    ]),
    admin_table.cell(when_column(), [
      html.span([attribute.class("admin-table__value--primary")], [
        html.text(timestamp_helpers.relative_label(log.created_at, now)),
      ]),
    ]),
    admin_table.cell(language_column(), [
      admin_table.stack([
        html.span([attribute.class("admin-table__value--primary")], [
          html.text(language.name(log.language)),
        ]),
      ]),
    ]),
    admin_table.cell(outcome_column(), [outcome_badge(log)]),
    admin_table.cell(duration_column(), [
      html.text(optional_duration(log.duration_ns)),
    ]),
    admin_table.cell(open_column(), [
      admin_ui.secondary_link([route.href(route.AdminRunLog(log.id))], "Open"),
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
  admin_table.action_column("Open")
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

fn parse_uuid_filter(
  value: String,
  label: String,
) -> Result(option.Option(uuid.Uuid), String) {
  let trimmed = string.trim(value)

  case trimmed == "" {
    True -> Ok(option.None)
    False ->
      case uuid.from_string(trimmed) {
        Ok(id) -> Ok(option.Some(id))
        Error(_) -> Error(label <> " must be a valid UUID.")
      }
  }
}

fn parse_language_filter(
  value: String,
) -> Result(option.Option(language.Language), String) {
  case value {
    "all" -> Ok(option.None)
    selected ->
      case language.from_string(selected) {
        option.Some(language) -> Ok(option.Some(language))
        option.None -> Error("Language must be a known runtime.")
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

fn empty_page() -> pagination_model.CursorPage(run_log_dto.RunLogResponse) {
  pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
}

fn can_go_previous(model: Model) -> Bool {
  case pagination_model.previous_cursor(current_page(model)) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn can_go_next(model: Model) -> Bool {
  case pagination_model.next_cursor(current_page(model)) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn outcome_badge(log: run_log_dto.RunLogResponse) -> Element(Msg) {
  case log.outcome {
    run_log_model.RunSucceeded ->
      admin_ui.badge(outcome_text(log.outcome), admin_ui.SuccessTone)
    run_log_model.RunFailed ->
      admin_ui.badge(outcome_text(log.outcome), admin_ui.DangerTone)
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

fn bool_attribute(value: Bool) -> String {
  case value {
    True -> "true"
    False -> "false"
  }
}
