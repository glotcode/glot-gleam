import gleam/list
import gleam/option
import gleam/string
import glot_core/admin/email_template_dto
import glot_frontend/admin_format
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/loadable
import glot_frontend/mutation
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(
    name: String,
    template: loadable.Loadable(email_template_dto.EmailTemplateDetailResponse),
    draft: Draft,
    save_state: mutation.MutationState,
  )
}

pub type Draft {
  Draft(
    subject_template: String,
    text_body_template: String,
    html_body_template: String,
  )
}

pub type Msg {
  TemplateLoaded(api.ApiResponse(email_template_dto.GetEmailTemplateResponse))
  SubjectChanged(String)
  TextBodyChanged(String)
  HtmlBodyChanged(String)
  ResetClicked
  SaveClicked
  SaveFinished(api.ApiResponse(email_template_dto.UpdateEmailTemplateResponse))
}

pub fn init(name: String) -> #(Model, Effect(Msg)) {
  #(
    Model(
      name: name,
      template: loadable.NotLoaded,
      draft: empty_draft(),
      save_state: mutation.Idle,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case
    loadable.ensure_loaded(
      model.template,
      api.get_admin_email_template(
        email_template_dto.GetEmailTemplateRequest(name: model.name),
        TemplateLoaded,
      ),
    )
  {
    #(template, next_effect) -> #(
      Model(..model, template: template),
      next_effect,
    )
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    TemplateLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let template = response.template
          #(
            Model(
              ..model,
              template: loadable.Loaded(template),
              draft: draft_from_template(template),
              save_state: mutation.Idle,
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, template: loadable.LoadError(api.error_message(error))),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            template: loadable.LoadError("Could not load email template."),
          ),
          effect.none(),
        )
      }

    SubjectChanged(value) -> #(
      Model(
        ..model,
        draft: Draft(..model.draft, subject_template: value),
        save_state: mutation.clear_feedback(model.save_state),
      ),
      effect.none(),
    )

    TextBodyChanged(value) -> #(
      Model(
        ..model,
        draft: Draft(..model.draft, text_body_template: value),
        save_state: mutation.clear_feedback(model.save_state),
      ),
      effect.none(),
    )

    HtmlBodyChanged(value) -> #(
      Model(
        ..model,
        draft: Draft(..model.draft, html_body_template: value),
        save_state: mutation.clear_feedback(model.save_state),
      ),
      effect.none(),
    )

    ResetClicked ->
      case model.template {
        loadable.Loaded(template) -> #(
          Model(
            ..model,
            draft: draft_from_template(template),
            save_state: mutation.Idle,
          ),
          effect.none(),
        )
        _ -> #(model, effect.none())
      }

    SaveClicked ->
      case request_from_draft(model) {
        Error(message) -> #(
          Model(..model, save_state: mutation.SaveError(message)),
          effect.none(),
        )
        Ok(request) -> #(
          Model(..model, save_state: mutation.Saving),
          api.update_admin_email_template(request, SaveFinished),
        )
      }

    SaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> {
          let template = response.template
          #(
            Model(
              ..model,
              template: loadable.Loaded(template),
              draft: draft_from_template(template),
              save_state: mutation.Saved,
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            save_state: mutation.SaveError(api.error_message(error)),
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            save_state: mutation.SaveError("Could not save email template."),
          ),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  admin_ui.page_with_panel_class(
    panel_class: "admin-job-page",
    title: "Email template detail",
    intro: "Template token validation runs in the backend on save, so the editor can stay simple while preserving long-term safety.",
    actions: [
      admin_ui.secondary_button(
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
    loadable.LoadError(message), _ -> admin_ui.error_status(message)
    loadable.Loading, _ -> admin_ui.status("Loading email template...")
    _, save_state ->
      admin_ui.mutation_status(
        save_state,
        "Saving email template...",
        "Email template saved.",
      )
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.template,
    admin_ui.empty_state("This email template could not be loaded."),
    admin_ui.empty_state("Loading email template..."),
    fn(template) {
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class(admin_ui.summary_grid_class())], [
          admin_ui.summary_card_with_class(
            "admin-page__policy admin-periodic-jobs-page__summary-card",
            "Template name",
            template.name,
          ),
          admin_ui.summary_card_with_class(
            "admin-page__policy admin-periodic-jobs-page__summary-card",
            "Supported tokens",
            tokens_text(template.supported_tokens),
          ),
          admin_ui.summary_card_with_class(
            "admin-page__policy admin-periodic-jobs-page__summary-card",
            "Updated at",
            admin_format.format_timestamp(template.updated_at),
          ),
        ]),
        admin_ui.section(
          title: "Metadata",
          copy: "Only known template names are editable, which keeps the route, validation rules, and DB rows aligned.",
          content: html.div([attribute.class(admin_ui.detail_grid_class())], [
            admin_ui.detail_item("Template name", template.name),
            admin_ui.detail_item(
              "Supported tokens",
              tokens_text(template.supported_tokens),
            ),
            admin_ui.detail_item(
              "Updated at",
              admin_format.format_timestamp(template.updated_at),
            ),
          ]),
        ),
        admin_ui.section(
          title: "Editor",
          copy: "Leave the HTML body empty to store no HTML variant for this email.",
          content: html.div([attribute.class("admin-snippets-page__filters")], [
            admin_ui.text_input(
              label: "Subject template",
              help: "Rendered subject line.",
              value: model.draft.subject_template,
              placeholder: "",
              on_input: SubjectChanged,
            ),
            admin_ui.textarea_input_with_attrs(
              label: "Text body template",
              help: "Plain text body sent to all recipients.",
              value: model.draft.text_body_template,
              rows: 10,
              field_class: "",
              textarea_class: "admin-periodic-jobs-page__payload-input",
              textarea_attributes: [],
              on_input: TextBodyChanged,
            ),
            admin_ui.textarea_input_with_attrs(
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
    fn(_) { admin_ui.empty_state("This email template could not be loaded.") },
  )
}

fn draft_from_template(
  template: email_template_dto.EmailTemplateDetailResponse,
) -> Draft {
  Draft(
    subject_template: template.subject_template,
    text_body_template: template.text_body_template,
    html_body_template: option.unwrap(template.html_body_template, ""),
  )
}

fn request_from_draft(
  model: Model,
) -> Result(email_template_dto.UpdateEmailTemplateRequest, String) {
  case string.trim(model.draft.subject_template) == "" {
    True -> Error("Subject template cannot be empty.")
    False ->
      case string.trim(model.draft.text_body_template) == "" {
        True -> Error("Text body template cannot be empty.")
        False ->
          Ok(email_template_dto.UpdateEmailTemplateRequest(
            name: model.name,
            subject_template: model.draft.subject_template,
            text_body_template: model.draft.text_body_template,
            html_body_template: normalize_html(model.draft.html_body_template),
          ))
      }
  }
}

fn normalize_html(value: String) -> option.Option(String) {
  case string.trim(value) == "" {
    True -> option.None
    False -> option.Some(value)
  }
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

fn empty_draft() -> Draft {
  Draft(subject_template: "", text_body_template: "", html_body_template: "")
}
