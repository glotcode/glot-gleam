import gleam/option
import gleam/regexp
import glot_core/email/email_address_model
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub type Model {
  Model(email: String, status: Status)
}

pub type Status {
  Idle
  Sending
  Success
  Error(message: String)
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model(email: "", status: Idle), effect.none())
}

pub type Msg {
  EmailChanged(String)
  Submit
  LoginTokenSent(api.ApiResponse(Nil))
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    EmailChanged(email) -> #(Model(email: email, status: Idle), effect.none())

    Submit -> {
      let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)

      case email_address_model.from_string(is_email, model.email) {
        option.Some(email) -> {
          let next_model = Model(..model, status: Sending)
          #(next_model, api.send_login_token(email, LoginTokenSent))
        }

        option.None -> {
          #(
            Model(..model, status: Error("Please enter a valid email address.")),
            effect.none(),
          )
        }
      }
    }

    LoginTokenSent(result) -> {
      case result {
        api.ApiSuccess(_) -> #(Model(..model, status: Success), effect.none())
        api.ApiFailure(error) -> {
          #(Model(..model, status: Error(error.message)), effect.none())
        }
        api.HttpFailure(_) -> {
          #(
            Model(..model, status: Error("Could not send login email.")),
            effect.none(),
          )
        }
      }
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("login-page")], [
    html.h2([attribute.class("login-page__title")], [html.text("Login")]),
    html.form(
      [
        event.on_submit(fn(_) { Submit }),
        attribute.class("login-page__form"),
      ],
      [
        html.label(
          [attribute.for("email"), attribute.class("login-page__label")],
          [html.text("Email")],
        ),
        html.input([
          attribute.id("email"),
          attribute.name("email"),
          attribute.type_("email"),
          attribute.placeholder("you@example.com"),
          attribute.value(model.email),
          event.on_input(EmailChanged),
          attribute.disabled(is_submitting(model.status)),
          attribute.class("login-page__input"),
        ]),
        status_view(model.status),
        html.button(
          [
            attribute.type_("submit"),
            attribute.disabled(is_submitting(model.status)),
            attribute.class("login-page__button"),
          ],
          [html.text(button_text(model.status))],
        ),
      ],
    ),
  ])
}

fn status_view(status: Status) -> Element(Msg) {
  case status {
    Idle -> html.text("")
    Sending ->
      html.p([attribute.class("login-page__status")], [
        html.text("Sending login email..."),
      ])
    Success ->
      html.p([attribute.class("login-page__status")], [
        html.text("Login email sent."),
      ])
    Error(message) ->
      html.p([attribute.class("login-page__status login-page__status--error")], [
        html.text(message),
      ])
  }
}

fn is_submitting(status: Status) -> Bool {
  case status {
    Sending -> True
    _ -> False
  }
}

fn button_text(status: Status) -> String {
  case status {
    Sending -> "Submitting..."
    _ -> "Submit"
  }
}
