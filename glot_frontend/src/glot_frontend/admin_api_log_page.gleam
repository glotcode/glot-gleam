import gleam/int
import gleam/option
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/api_log_dto
import glot_core/route
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import youid/uuid

pub type Model {
  Model(
    request_id: uuid.Uuid,
    log: option.Option(api_log_dto.ApiLogDetailResponse),
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
  LogLoaded(api.ApiResponse(api_log_dto.GetApiLogResponse))
}

pub fn init(request_id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(
    Model(request_id: request_id, log: option.None, status: NotLoaded),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded ->
      #(
        Model(..model, status: Loading),
        api.get_admin_api_log(
          api_log_dto.GetApiLogRequest(request_id: model.request_id),
          LogLoaded,
        ),
      )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    LogLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, log: option.Some(response.log), status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load API log.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section(
        [attribute.class("app-panel admin-page admin-request-log-page")],
        [
          html.div([attribute.class("admin-page__header")], [
            html.div([], [
              html.h2([attribute.class("admin-page__title")], [
                html.text("API log detail"),
              ]),
              html.p([attribute.class("admin-page__status")], [
                html.text(
                  "Inspect the API log captured for one request.",
                ),
              ]),
            ]),
            html.div([attribute.class("admin-page__policy-actions")], [
              html.a(
                [
                  attribute.class("admin-page__button admin-page__button--secondary"),
                  route.href(route.AdminApiLogs),
                ],
                [html.text("Back to API logs")],
              ),
            ]),
          ]),
          status_view(model),
          detail_view(model),
        ],
      ),
    ]),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading API log..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.log, model.status {
    option.None, Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading API log..."),
      ])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This API log could not be loaded."),
      ])
    option.Some(log), _ ->
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class("admin-job-page__summary-grid admin-request-log-page__summary-grid")], [
          summary_card("Request ID", uuid.to_string(log.request_id), "Primary identifier"),
          summary_card("Created at", format_timestamp(log.created_at), "UTC"),
          summary_card("Action", log.log.action, "Captured API request"),
        ]),
        section_view(
          "API log",
          "Request-handling metadata and raw API log payloads.",
          option.Some(api_log_content(log.log)),
          "",
        ),
      ])
  }
}

fn section_view(
  title: String,
  copy: String,
  content: option.Option(Element(Msg)),
  empty_message: String,
) -> Element(Msg) {
  html.div([attribute.class("admin-page__group")], [
    html.div([attribute.class("admin-page__group-header")], [
      html.h3([attribute.class("admin-page__group-title")], [html.text(title)]),
      html.p([attribute.class("admin-page__group-copy")], [html.text(copy)]),
    ]),
    case content {
      option.Some(content) -> content
      option.None ->
        html.div([attribute.class("admin-page__empty")], [html.text(empty_message)])
    },
  ])
}

fn api_log_content(log: api_log_dto.ApiLogEntryResponse) -> Element(Msg) {
  html.div([attribute.class("admin-request-log-page__section")], [
    html.div([attribute.class("admin-job-page__detail-grid")], [
      detail_item("Created at", format_timestamp(log.created_at)),
      detail_item("Action", log.action),
      detail_item("Body bytes", int.to_string(log.body_bytes)),
      detail_item("Duration ns", int.to_string(log.duration_ns)),
      detail_item("IP", optional_text(log.ip)),
      detail_item("User agent", optional_text(log.user_agent)),
    ]),
    raw_blocks(log.info, log.warnings, log.debug, log.error, log.effects),
  ])
}

fn summary_card(title: String, value: String, meta: String) -> Element(Msg) {
  html.article(
    [attribute.class("admin-page__policy admin-job-page__summary-card")],
    [
      html.span([attribute.class("admin-job-page__eyebrow")], [html.text(title)]),
      html.strong([attribute.class("admin-job-page__summary-value")], [html.text(value)]),
      html.span([attribute.class("admin-job-page__meta")], [html.text(meta)]),
    ],
  )
}

fn detail_item(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-job-page__detail-item")], [
    html.span([attribute.class("admin-job-page__eyebrow")], [html.text(label)]),
    html.span([attribute.class("admin-job-page__detail-value")], [html.text(value)]),
  ])
}

fn raw_blocks(
  info: option.Option(String),
  warnings: option.Option(String),
  debug: option.Option(String),
  error: option.Option(String),
  effects: option.Option(String),
) -> Element(Msg) {
  html.div([attribute.class("admin-request-log-page__raw-grid")], [
    raw_block("Info", info),
    raw_block("Warnings", warnings),
    raw_block("Debug", debug),
    raw_block("Error", error),
    raw_block("Effects", effects),
  ])
}

fn raw_block(title: String, value: option.Option(String)) -> Element(Msg) {
  html.div([attribute.class("admin-page__group")], [
    html.h4([attribute.class("admin-page__group-title")], [html.text(title)]),
    html.div([attribute.class("admin-page__policy")], [
      html.pre([attribute.class("admin-job-page__code-block")], [
        html.text(optional_text(value)),
      ]),
    ]),
  ])
}

fn format_timestamp(value) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}

fn optional_text(value: option.Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> "None"
  }
}
