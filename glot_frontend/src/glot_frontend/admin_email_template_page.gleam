import gleam/list
import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/admin/email_template_dto
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
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-job-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Email template detail"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "Template token validation runs in the backend on save, so the editor can stay simple while preserving long-term safety.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            html.button(
              [
                attribute.class(
                  "admin-page__button admin-page__button--secondary",
                ),
                attribute.type_("button"),
                attribute.disabled(
                  model.template == option.None || model.save_state == Saving,
                ),
                event.on_click(ResetClicked),
              ],
              [html.text("Reset")],
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
          ]),
        ]),
        status_view(model),
        detail_view(model),
      ]),
    ]),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status, model.save_state {
    LoadError(message), _ -> error_status(message)
    Loading, _ -> plain_status("Loading email template...")
    _, SaveError(message) -> error_status(message)
    _, Saving -> plain_status("Saving email template...")
    _, Saved -> plain_status("Email template saved.")
    _, Idle -> plain_status("")
  }
}

fn detail_view(model: Model) -> Element(Msg) {
  case model.template, model.status {
    option.None, Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading email template..."),
      ])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This email template could not be loaded."),
      ])
    option.Some(template), _ ->
      html.div([attribute.class("admin-job-page__content")], [
        html.div([attribute.class("admin-job-page__summary-grid")], [
          summary_card("Name", template.name),
          summary_card(
            "Supported tokens",
            tokens_text(template.supported_tokens),
          ),
          summary_card("Updated at", format_timestamp(template.updated_at)),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Metadata"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Only known template names are editable, which keeps the route, validation rules, and DB rows aligned.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-job-page__detail-grid")], [
            detail_item("Template name", template.name),
            detail_item(
              "Supported tokens",
              tokens_text(template.supported_tokens),
            ),
            detail_item("Updated at", format_timestamp(template.updated_at)),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.h3([attribute.class("admin-page__group-title")], [
              html.text("Editor"),
            ]),
            html.p([attribute.class("admin-page__group-copy")], [
              html.text(
                "Leave the HTML body empty to store no HTML variant for this email.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-snippets-page__filters")], [
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
        ]),
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

fn plain_status(message: String) -> Element(Msg) {
  html.p([attribute.class("admin-page__status")], [html.text(message)])
}

fn error_status(message: String) -> Element(Msg) {
  html.p([attribute.class("admin-page__status admin-page__status--error")], [
    html.text(message),
  ])
}

fn summary_card(title: String, value: String) -> Element(Msg) {
  html.div(
    [
      attribute.class(
        "admin-page__policy admin-periodic-jobs-page__summary-card",
      ),
    ],
    [
      html.span([attribute.class("admin-job-page__eyebrow")], [html.text(title)]),
      html.span([attribute.class("admin-job-page__summary-value")], [
        html.text(value),
      ]),
    ],
  )
}

fn detail_item(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-job-page__detail-item")], [
    html.span([attribute.class("admin-job-page__eyebrow")], [html.text(label)]),
    html.span([attribute.class("admin-job-page__detail-value")], [
      html.text(value),
    ]),
  ])
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
