import gleam/int
import gleam/list
import gleam/option
import glot_core/contact_dto
import glot_core/email/email_address_model.{type EmailAddress}
import glot_frontend/public/contact/command
import glot_frontend/public/contact/interpreter
import glot_frontend/public/contact/managed
import glot_frontend/public/contact/message.{
  EmailChanged, MessageChanged, SubmittedForm, TopicChanged, WebsiteChanged,
}
import glot_frontend/public/contact/model.{
  Idle, SubmitError, Submitted, Submitting,
}
import glot_frontend/public/contact/production_ports
import glot_web/page/contact
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model =
  model.Model

pub type Msg =
  message.Msg

pub type Status =
  model.Status

pub fn init(email: option.Option(EmailAddress)) -> #(Model, Effect(Msg)) {
  #(managed.init(email), effect.none())
}

pub fn session_loaded(
  model: Model,
  email: option.Option(EmailAddress),
) -> Model {
  managed.session_loaded(model, email)
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  let #(model, command) = managed.update(model, msg)
  #(model, interpreter.run(command, using: production_ports.new()))
}

pub fn update_managed(
  model: Model,
  msg: Msg,
) -> #(Model, command.Command(Msg)) {
  managed.update(model, msg)
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
