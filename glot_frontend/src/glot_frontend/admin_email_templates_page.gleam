import gleam/list
import glot_core/admin/email_template_dto
import glot_core/route
import glot_frontend/admin_format
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_core/loadable
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html

pub type Model {
  Model(
    templates: loadable.Loadable(
      List(email_template_dto.EmailTemplateSummaryResponse),
    ),
  )
}

pub type Msg {
  TemplatesLoaded(
    api.ApiResponse(email_template_dto.ListEmailTemplatesResponse),
  )
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model(templates: loadable.NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case
    loadable.ensure_loaded(
      model.templates,
      api.get_admin_email_templates(TemplatesLoaded),
    )
  {
    #(templates, next_effect) -> #(Model(templates: templates), next_effect)
  }
}

pub fn update(_model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    TemplatesLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(templates: loadable.Loaded(response.templates)),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(templates: loadable.LoadError(api.error_message(error))),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(templates: loadable.LoadError("Could not load email templates.")),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  admin_ui.page_with_panel_class(
    panel_class: "admin-jobs-page",
    title: "Email templates",
    intro: "This directory is read-only. Open a template to edit the stored subject and body content.",
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
        admin_ui.loadable_status(model.templates, "Loading email templates..."),
        templates_view(model),
      ]),
    ],
  )
}

fn templates_view(model: Model) -> Element(Msg) {
  admin_ui.loadable_list_content(
    model.templates,
    "Loading email templates...",
    "No email templates were found.",
    templates_table,
  )
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
      admin_table.secondary_value(admin_format.format_timestamp(
        template.updated_at,
      )),
    ]),
    admin_table.cell(open_column(), [
      admin_ui.secondary_link(
        [route.href(route.Admin(route.AdminEmailTemplate(template.name)))],
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
