import gleam/list
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/email_template_dto
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
  admin_ui.page_with_panel_class(
    panel_class: "admin-jobs-page",
    title: "Email templates",
    intro:
      "This directory is read-only. Open a template to edit the stored subject and body content.",
    actions: [],
    content: [
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
    ],
  )
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
  admin_table.table(template_columns(), templates |> list.map(template_row))
}

fn template_row(
  template: email_template_dto.EmailTemplateSummaryResponse,
) -> Element(Msg) {
  admin_table.row([
    admin_table.cell(name_column(), [admin_table.primary_value(template.name)]),
    admin_table.cell(updated_at_column(), [
      admin_table.secondary_value(format_timestamp(template.updated_at)),
    ]),
    admin_table.cell(open_column(), [
      admin_ui.secondary_link(
        [route.href(route.AdminEmailTemplate(template.name))],
        "Open",
      ),
    ]),
  ])
}

fn template_columns() -> List(admin_table.Column) {
  [name_column(), updated_at_column(), open_column()]
}

fn name_column() -> admin_table.Column {
  admin_table.column("Name")
}

fn updated_at_column() -> admin_table.Column {
  admin_table.column("Updated at")
}

fn open_column() -> admin_table.Column {
  admin_table.action_column("Open")
}

fn format_timestamp(value) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
