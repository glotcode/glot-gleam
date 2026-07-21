import gleam/list
import gleam/option
import gleam/string
import glot_core/loadable
import glot_frontend/admin/email_templates/detail_message.{
  type Msg, HtmlBodyChanged, ResetClicked, SaveClicked, SubjectChanged,
  TextBodyChanged,
}
import glot_frontend/admin/email_templates/detail_model.{type Model}
import glot_frontend/admin/ui/form as admin_form
import glot_frontend/admin/ui/format as admin_format
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/admin/ui/status as admin_status
import glot_frontend/ui/mutation
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn view(model: Model) -> Element(Msg) {
  admin_layout.page_with_panel_class(
    panel_class: "admin-job-page",
    title: "Email template detail",
    intro: "Template token validation runs in the backend on save, so the editor can stay simple while preserving long-term safety.",
    actions: [
      admin_layout.secondary_button(
        [
          attribute.type_("button"),
          attribute.disabled(
            loadable.to_option(model.template) == option.None
            || mutation.is_saving(model.save_state),
          ),
          event.on_click(ResetClicked),
        ],
        "Reset",
      ),
      html.button(
        [
          attribute.class("admin-page__button"),
          attribute.type_("button"),
          attribute.disabled(
            loadable.to_option(model.template) == option.None
            || mutation.is_saving(model.save_state),
          ),
          event.on_click(SaveClicked),
        ],
        [html.text(save_button_label(model.save_state))],
      ),
    ],
    content: [template_status(model), detail_view(model)],
  )
}

fn template_status(model: Model) -> Element(Msg) {
  case model.template, model.save_state {
    loadable.LoadError(message), _ -> admin_status.error_status(message)
    loadable.Loading, _ -> admin_status.status("Loading email template...")
    _, save_state ->
      admin_status.mutation_status(
        save_state,
        "Saving email template...",
        "Email template saved.",
      )
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.template,
    admin_status.empty_state("This email template could not be loaded."),
    admin_status.empty_state("Loading email template..."),
    fn(template) {
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class(admin_layout.summary_grid_class())], [
          admin_layout.summary_card_with_class(
            "admin-page__policy admin-periodic-jobs-page__summary-card",
            "Template name",
            template.name,
          ),
          admin_layout.summary_card_with_class(
            "admin-page__policy admin-periodic-jobs-page__summary-card",
            "Supported tokens",
            tokens_text(template.supported_tokens),
          ),
          admin_layout.summary_card_with_class(
            "admin-page__policy admin-periodic-jobs-page__summary-card",
            "Updated at",
            admin_format.format_timestamp(template.updated_at),
          ),
        ]),
        admin_layout.section(
          title: "Metadata",
          copy: "Only known template names are editable, which keeps the route, validation rules, and DB rows aligned.",
          content: html.div(
            [attribute.class(admin_layout.detail_grid_class())],
            [
              admin_layout.detail_item("Template name", template.name),
              admin_layout.detail_item(
                "Supported tokens",
                tokens_text(template.supported_tokens),
              ),
              admin_layout.detail_item(
                "Updated at",
                admin_format.format_timestamp(template.updated_at),
              ),
            ],
          ),
        ),
        admin_layout.section(
          title: "Editor",
          copy: "Leave the HTML body empty to store no HTML variant for this email.",
          content: html.div([attribute.class("admin-snippets-page__filters")], [
            admin_form.text_input(
              label: "Subject template",
              help: "Rendered subject line.",
              value: model.draft.subject_template,
              placeholder: "",
              on_input: SubjectChanged,
            ),
            admin_form.textarea_input_with_attrs(
              label: "Text body template",
              help: "Plain text body sent to all recipients.",
              value: model.draft.text_body_template,
              rows: 10,
              field_class: "",
              textarea_class: "admin-periodic-jobs-page__payload-input",
              textarea_attributes: [],
              on_input: TextBodyChanged,
            ),
            admin_form.textarea_input_with_attrs(
              label: "HTML body template",
              help: "Optional HTML body.",
              value: model.draft.html_body_template,
              rows: 12,
              field_class: "",
              textarea_class: "admin-periodic-jobs-page__payload-input",
              textarea_attributes: [],
              on_input: HtmlBodyChanged,
            ),
          ]),
        ),
      ])
    },
    fn(_) {
      admin_status.empty_state("This email template could not be loaded.")
    },
  )
}

fn save_button_label(state: mutation.MutationState) -> String {
  case state {
    mutation.Saving -> "Saving..."
    mutation.Idle | mutation.Saved | mutation.SaveError(_) -> "Save"
  }
}

fn tokens_text(tokens: List(String)) -> String {
  case tokens {
    [] -> "No template tokens"
    _ ->
      tokens
      |> list.map(fn(token) { "{{" <> token <> "}}" })
      |> string.join(with: ", ")
  }
}
