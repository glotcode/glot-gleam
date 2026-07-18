import gleam/int
import gleam/list
import gleam/regexp
import glot_core/contact_dto
import glot_core/email/email_address_model
import glot_core/page/contact
import glot_core/validation_error
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(
    email: String,
    topic: String,
    message: String,
    website: String,
    status: Status,
  )
}

pub type Status {
  Idle
  Submitting
  Submitted
  SubmitError(String)
}

pub type Msg {
  EmailChanged(String)
  TopicChanged(String)
  MessageChanged(String)
  WebsiteChanged(String)
  SubmittedForm
  SubmissionFinished(api.ApiResponse(Nil))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      email: "",
      topic: contact_dto.topic_to_string(contact_dto.Privacy),
      message: "",
      website: "",
      status: Idle,
    ),
    effect.none(),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    EmailChanged(value) -> #(
      Model(..model, email: value, status: clear_feedback(model.status)),
      effect.none(),
    )
    TopicChanged(value) -> #(
      Model(..model, topic: value, status: clear_feedback(model.status)),
      effect.none(),
    )
    MessageChanged(value) -> #(
      Model(..model, message: value, status: clear_feedback(model.status)),
      effect.none(),
    )
    WebsiteChanged(value) -> #(
      Model(..model, website: value, status: clear_feedback(model.status)),
      effect.none(),
    )
    SubmittedForm -> submit(model)
    SubmissionFinished(result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, message: "", website: "", status: Submitted),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: SubmitError(api.error_message(error))),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            status: SubmitError(
              "The message could not be sent. Please try again.",
            ),
          ),
          effect.none(),
        )
      }
  }
}

fn submit(model: Model) -> #(Model, Effect(Msg)) {
  let request = request_from_model(model)
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  case contact_dto.validate(request, is_email) {
    Ok(_) -> #(
      Model(..model, status: Submitting),
      api.submit_contact(request, SubmissionFinished),
    )
    Error(err) -> #(
      Model(..model, status: SubmitError(validation_error.message(err))),
      effect.none(),
    )
  }
}

fn request_from_model(model: Model) -> contact_dto.ContactRequest {
  contact_dto.ContactRequest(
    email: model.email,
    topic: model.topic,
    message: model.message,
    website: model.website,
  )
}

fn clear_feedback(status: Status) -> Status {
  case status {
    Submitting -> Submitting
    Idle | Submitted | SubmitError(_) -> Idle
  }
}

pub fn view(model: Model) -> Element(Msg) {
  contact.view(contact_form(model))
}

fn contact_form(model: Model) -> Element(Msg) {
  let busy = model.status == Submitting
  html.form(
    [attribute.class("contact-form"), event.on_submit(fn(_) { SubmittedForm })],
    [
      html.div([attribute.class("contact-form__grid")], [
        html.label([attribute.class("contact-form__field")], [
          html.span([], [html.text("Your email")]),
          html.input([
            attribute.type_("email"),
            attribute.name("email"),
            attribute.autocomplete("email"),
            attribute.placeholder("you@example.com"),
            attribute.value(model.email),
            attribute.disabled(busy),
            attribute.attribute("required", ""),
            event.on_input(EmailChanged),
          ]),
        ]),
        html.label([attribute.class("contact-form__field")], [
          html.span([], [html.text("Topic")]),
          html.select(
            [
              attribute.name("topic"),
              attribute.value(model.topic),
              attribute.disabled(busy),
              event.on_input(TopicChanged),
            ],
            list.map(contact_dto.topics(), fn(topic) {
              let value = contact_dto.topic_to_string(topic)
              html.option(
                [
                  attribute.value(value),
                  attribute.selected(value == model.topic),
                ],
                contact_dto.topic_label(topic),
              )
            }),
          ),
        ]),
      ]),
      html.label([attribute.class("contact-form__field")], [
        html.span([], [html.text("Message")]),
        html.textarea(
          [
            attribute.name("message"),
            attribute.rows(7),
            attribute.maxlength(contact_dto.max_message_length),
            attribute.disabled(busy),
            attribute.attribute("required", ""),
            event.on_input(MessageChanged),
          ],
          model.message,
        ),
        html.span([attribute.class("contact-form__help")], [
          html.text(
            int.to_string(contact_dto.max_message_length)
            <> " characters maximum.",
          ),
        ]),
      ]),
      html.label(
        [
          attribute.class("contact-form__honeypot"),
          attribute.attribute("aria-hidden", "true"),
        ],
        [
          html.span([], [html.text("Website")]),
          html.input([
            attribute.type_("text"),
            attribute.name("website"),
            attribute.autocomplete("off"),
            attribute.attribute("tabindex", "-1"),
            attribute.value(model.website),
            event.on_input(WebsiteChanged),
          ]),
        ],
      ),
      status_view(model.status),
      html.button(
        [
          attribute.type_("submit"),
          attribute.class("contact-form__submit"),
          attribute.disabled(busy),
        ],
        [
          html.text(case model.status {
            Submitting -> "Sending…"
            _ -> "Send message"
          }),
        ],
      ),
    ],
  )
}

fn status_view(status: Status) -> Element(Msg) {
  case status {
    Idle | Submitting -> html.text("")
    Submitted ->
      status_message(
        "contact-form__status--success",
        "Your message has been sent.",
      )
    SubmitError(message) ->
      status_message("contact-form__status--error", message)
  }
}

fn status_message(class_name: String, message: String) -> Element(Msg) {
  html.p(
    [
      attribute.class("contact-form__status " <> class_name),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-live", "polite"),
    ],
    [html.text(message)],
  )
}
