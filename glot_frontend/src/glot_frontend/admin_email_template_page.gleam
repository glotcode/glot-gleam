import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/email_template_dto
import glot_frontend/admin_ui
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(
    name: String,
    template: option.Option(email_template_dto.EmailTemplateDetailResponse),
    draft: Draft,
    status: Status,
    save_state: SaveState,
  )
}

pub type Draft {
  Draft(
    subject_template: String,
    text_body_template: String,
    html_body_template: String,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type SaveState {
  Idle
  Saving
  Saved
  SaveError(String)
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
      template: option.None,
      draft: empty_draft(),
      status: NotLoaded,
      save_state: Idle,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      api.get_admin_email_template(
        email_template_dto.GetEmailTemplateRequest(name: model.name),
        TemplateLoaded,
      ),
    )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
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
              template: option.Some(template),
              draft: draft_from_template(template),
              status: Ready,
              save_state: Idle,
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load email template.")),
          effect.none(),
        )
      }

    SubjectChanged(value) -> #(
      Model(
        ..model,
        draft: Draft(..model.draft, subject_template: value),
        save_state: idle_state(model.save_state),
      ),
      effect.none(),
    )

    TextBodyChanged(value) -> #(
      Model(
        ..model,
        draft: Draft(..model.draft, text_body_template: value),
        save_state: idle_state(model.save_state),
      ),
      effect.none(),
    )

    HtmlBodyChanged(value) -> #(
      Model(
        ..model,
        draft: Draft(..model.draft, html_body_template: value),
        save_state: idle_state(model.save_state),
      ),
      effect.none(),
    )

    ResetClicked ->
      case model.template {
        option.Some(template) -> #(
          Model(..model, draft: draft_from_template(template), save_state: Idle),
          effect.none(),
        )
        option.None -> #(model, effect.none())
      }

    SaveClicked ->
      case request_from_draft(model) {
        Error(message) -> #(
          Model(..model, save_state: SaveError(message)),
          effect.none(),
        )
        Ok(request) -> #(
          Model(..model, save_state: Saving),
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
              template: option.Some(template),
              draft: draft_from_template(template),
              save_state: Saved,
            ),
            effect.none(),
          )
        }
        api.ApiFailure(error) -> #(
          Model(..model, save_state: SaveError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            save_state: SaveError("Could not save email template."),
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
    intro:
      "Template token validation runs in the backend on save, so the editor can stay simple while preserving long-term safety.",
    actions: [
      admin_ui.secondary_button(
        [
          attribute.type_("button"),
          attribute.disabled(
            model.template == option.None || model.save_state == Saving,
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
            model.template == option.None || model.save_state == Saving,
          ),
          event.on_click(SaveClicked),
        ],
        [html.text(save_button_label(model.save_state))],
      ),
    ],
    content: [status_view(model), detail_view(model)],
  )
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status, model.save_state {
    LoadError(message), _ -> admin_ui.error_status(message)
    Loading, _ -> admin_ui.status("Loading email template...")
    _, SaveError(message) -> admin_ui.error_status(message)
    _, Saving -> admin_ui.status("Saving email template...")
    _, Saved -> admin_ui.status("Email template saved.")
    _, Idle -> admin_ui.status("")
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.template, model.status {
    option.None, Loading -> admin_ui.empty_state("Loading email template...")
    option.None, _ ->
      admin_ui.empty_state("This email template could not be loaded.")
    option.Some(template), _ ->
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
            format_timestamp(template.updated_at),
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
              format_timestamp(template.updated_at),
            ),
          ]),
        ),
        admin_ui.section(
          title: "Editor",
          copy: "Leave the HTML body empty to store no HTML variant for this email.",
          content: html.div([attribute.class("admin-snippets-page__filters")], [
            text_input(
              label: "Subject template",
              help: "Rendered subject line.",
              value: model.draft.subject_template,
              on_input: SubjectChanged,
            ),
            textarea_input(
              label: "Text body template",
              help: "Plain text body sent to all recipients.",
              value: model.draft.text_body_template,
              rows: 10,
              on_input: TextBodyChanged,
            ),
            textarea_input(
              label: "HTML body template",
              help: "Optional HTML body.",
              value: model.draft.html_body_template,
              rows: 12,
              on_input: HtmlBodyChanged,
            ),
          ]),
        ),
      ])
  }
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
      attribute.class("admin-page__input"),
      attribute.type_("text"),
      attribute.value(value),
      event.on_input(on_input),
    ]),
    html.span([attribute.class("admin-page__field-help")], [html.text(help)]),
  ])
}

fn textarea_input(
  label label: String,
  help help: String,
  value value: String,
  rows rows: Int,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.textarea(
      [
        attribute.class(
          "admin-page__input admin-periodic-jobs-page__payload-input",
        ),
        attribute.rows(rows),
        event.on_input(on_input),
      ],
      value,
    ),
    html.span([attribute.class("admin-page__field-help")], [html.text(help)]),
  ])
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

fn save_button_label(state: SaveState) -> String {
  case state {
    Saving -> "Saving..."
    Idle | Saved | SaveError(_) -> "Save"
  }
}

fn idle_state(state: SaveState) -> SaveState {
  case state {
    Saving -> Saving
    Idle | Saved | SaveError(_) -> Idle
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

fn format_timestamp(value) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
