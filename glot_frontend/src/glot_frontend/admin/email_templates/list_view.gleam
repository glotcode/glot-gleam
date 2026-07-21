import gleam/list
import glot_core/admin/email_template_dto
import glot_core/route
import glot_frontend/admin/email_templates/list_message.{type Msg}
import glot_frontend/admin/email_templates/list_model.{type Model}
import glot_frontend/admin/ui/format as admin_format
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/admin/ui/status as admin_status
import glot_frontend/admin/ui/table as admin_table
import glot_web/route as web_route
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

pub fn view(model: Model) -> Element(Msg) {
  admin_layout.page_with_panel_class(
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
        admin_status.loadable_status(
          model.templates,
          "Loading email templates...",
        ),
        templates_view(model),
      ]),
    ],
  )
}

fn templates_view(model: Model) -> Element(Msg) {
  admin_status.loadable_list_content(
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
      admin_layout.secondary_link(
        [web_route.href(route.Admin(route.AdminEmailTemplate(template.name)))],
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
