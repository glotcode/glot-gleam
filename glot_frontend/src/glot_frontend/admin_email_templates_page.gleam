import gleam/list
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/email_template_dto
import glot_core/route
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(
    templates: List(email_template_dto.EmailTemplateSummaryResponse),
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
  TemplatesLoaded(
    api.ApiResponse(email_template_dto.ListEmailTemplatesResponse),
  )
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model(templates: [], status: NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      api.get_admin_email_templates(TemplatesLoaded),
    )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    TemplatesLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(templates: response.templates, status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load email templates.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-jobs-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Email templates"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "This directory is read-only. Open a template to edit the stored subject and body content.",
              ),
            ]),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.div([], [
              html.h3([attribute.class("admin-page__group-title")], [
                html.text("Templates"),
              ]),
              html.p([attribute.class("admin-page__group-copy")], [
                html.text("Open a template row to edit its stored content."),
              ]),
            ]),
          ]),
          status_view(model),
          templates_view(model),
        ]),
      ]),
    ]),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [html.text("")])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
        html.text("Loading email templates..."),
      ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn templates_view(model: Model) -> Element(Msg) {
  case model.templates, model.status {
    [], Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading email templates..."),
      ])
    [], _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No email templates were found."),
      ])
    templates, _ -> templates_table(templates)
  }
}

fn templates_table(
  templates: List(email_template_dto.EmailTemplateSummaryResponse),
) -> Element(Msg) {
  html.div([attribute.class("admin-data-table__wrap")], [
    html.table([attribute.class("admin-data-table")], [
      html.thead([], [
        html.tr([], [
          table_heading("Name"),
          table_heading("Updated at"),
          table_heading("Open"),
        ]),
      ]),
      html.tbody([], templates |> list.map(template_row)),
    ]),
  ])
}

fn template_row(
  template: email_template_dto.EmailTemplateSummaryResponse,
) -> Element(Msg) {
  html.tr([], [
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Name"),
      html.span(
        [attribute.class("admin-data-table__value jobs-table__primary")],
        [
          html.text(template.name),
        ],
      ),
    ]),
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Updated at"),
      html.span(
        [attribute.class("admin-data-table__value jobs-table__secondary")],
        [
          html.text(format_timestamp(template.updated_at)),
        ],
      ),
    ]),
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Open"),
      html.a(
        [
          attribute.class("admin-page__button admin-page__button--secondary"),
          route.href(route.AdminEmailTemplate(template.name)),
        ],
        [html.text("Open")],
      ),
    ]),
  ])
}

fn table_heading(text: String) -> Element(Msg) {
  html.th([attribute.class("admin-data-table__heading")], [html.text(text)])
}

fn cell_label(text: String) -> Element(Msg) {
  html.span([attribute.class("admin-data-table__label")], [html.text(text)])
}

fn format_timestamp(value) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
