import gleam/option
import gleam/regexp
import gleam/string
import glot_core/email/email_address_model
import glot_core/route
import glot_frontend/api
import glot_frontend/app_event
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem

pub type Model {
  Model(email: String, token: String, step: Step, status: Status)
}

pub type Step {
  EnterEmail
  EnterToken(email: email_address_model.EmailAddress)
}

pub type Status {
  Idle
  SendingToken
  LoggingIn
  Info(message: String)
  Error(message: String)
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(Model(email: "", token: "", step: EnterEmail, status: Idle), effect.none())
}

pub type Msg {
  EmailChanged(String)
  TokenChanged(String)
  SendTokenSubmitted
  LoginSubmitted
  LoginTokenSent(api.ApiResponse(Nil))
  LoggedIn(api.ApiResponse(Nil))
}

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg), app_event.AppEvent) {
  case msg {
    EmailChanged(email) -> {
      #(
        Model(email: email, token: "", step: EnterEmail, status: Idle),
        effect.none(),
        app_event.NoAppEvent,
      )
    }

    TokenChanged(token) -> #(
      Model(..model, token: token, status: Idle),
      effect.none(),
      app_event.NoAppEvent,
    )

    SendTokenSubmitted -> {
      let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)

      case email_address_model.from_string(is_email, model.email) {
        option.Some(email) -> {
          let next_model =
            Model(..model, step: EnterEmail, status: SendingToken)
          #(
            next_model,
            api.send_login_token(email, LoginTokenSent),
            app_event.NoAppEvent,
          )
        }

        option.None -> {
          #(
            Model(
              ..model,
              step: EnterEmail,
              status: Error("Please enter a valid email address."),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }
      }
    }

    LoginSubmitted -> {
      case model.step {
        EnterEmail -> #(model, effect.none(), app_event.NoAppEvent)

        EnterToken(email) -> {
          let token = string.trim(model.token)

          case token == "" {
            True -> {
              #(
                Model(..model, status: Error("Please enter the login token.")),
                effect.none(),
                app_event.NoAppEvent,
              )
            }

            False -> {
              let next_model = Model(..model, status: LoggingIn)
              #(
                next_model,
                api.login(email, token, LoggedIn),
                app_event.NoAppEvent,
              )
            }
          }
        }
      }
    }

    LoginTokenSent(result) -> {
      let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)

      case result, email_address_model.from_string(is_email, model.email) {
        api.ApiSuccess(_), option.Some(email) -> {
          #(
            Model(
              ..model,
              step: EnterToken(email),
              token: "",
              status: Info("A login token has been sent to your email."),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }

        api.ApiSuccess(_), option.None -> {
          #(
            Model(
              ..model,
              step: EnterEmail,
              status: Error("Please enter a valid email address."),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }

        api.ApiFailure(error), _ -> {
          #(
            Model(
              ..model,
              step: EnterEmail,
              status: Error(api.error_message(error)),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }

        api.HttpFailure(_), _ -> {
          #(
            Model(
              ..model,
              step: EnterEmail,
              status: Error("Could not send login email."),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }
      }
    }

    LoggedIn(result) -> {
      case result {
        api.ApiSuccess(_) -> {
          #(
            Model(..model, status: Info("You are now logged in.")),
            modem.replace(
              route.to_string(route.Public(route.Home)),
              option.None,
              option.None,
            ),
            app_event.RefreshSession,
          )
        }

        api.ApiFailure(error) -> {
          #(
            Model(..model, status: Error(api.error_message(error))),
            effect.none(),
            app_event.NoAppEvent,
          )
        }

        api.HttpFailure(_) -> {
          #(
            Model(..model, status: Error("Could not complete login.")),
            effect.none(),
            app_event.NoAppEvent,
          )
        }
      }
    }
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell app-shell--narrow")], [
      html.section([attribute.class("app-panel")], [
        html.h2([attribute.class("login-page__title")], [html.text("Login")]),
        html.p([attribute.class("login-page__status")], [
          html.text("No account yet? We’ll create one when you sign in."),
        ]),
        html.form(
          [
            event.on_submit(fn(_) { submit_msg(model.step) }),
            attribute.class("login-page__form"),
          ],
          form_fields(model),
        ),
      ]),
    ]),
  ])
}

fn form_fields(model: Model) -> List(Element(Msg)) {
  case model.step {
    EnterEmail -> [
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
        [html.text(button_text(model.status, model.step))],
      ),
    ]

    EnterToken(_email) -> [
      html.p([attribute.class("login-page__status")], []),
      status_view(model.status),
      html.label(
        [attribute.for("token"), attribute.class("login-page__label")],
        [html.text("Token")],
      ),
      html.input([
        attribute.id("token"),
        attribute.name("token"),
        attribute.type_("text"),
        attribute.placeholder("Enter login token"),
        attribute.value(model.token),
        event.on_input(TokenChanged),
        attribute.disabled(is_submitting(model.status)),
        attribute.class("login-page__input"),
      ]),
      html.button(
        [
          attribute.type_("submit"),
          attribute.disabled(is_submitting(model.status)),
          attribute.class("login-page__button"),
        ],
        [html.text(button_text(model.status, model.step))],
      ),
    ]
  }
}

fn status_view(status: Status) -> Element(Msg) {
  case status {
    Idle -> html.text("")
    SendingToken ->
      html.p([attribute.class("login-page__status")], [
        html.text("Sending login email..."),
      ])
    LoggingIn ->
      html.p([attribute.class("login-page__status")], [
        html.text("Logging in..."),
      ])
    Info(message) ->
      html.p([attribute.class("login-page__status")], [
        html.text(message),
      ])
    Error(message) ->
      html.p([attribute.class("login-page__status login-page__status--error")], [
        html.text(message),
      ])
  }
}

fn is_submitting(status: Status) -> Bool {
  case status {
    SendingToken | LoggingIn -> True
    _ -> False
  }
}

fn submit_msg(step: Step) -> Msg {
  case step {
    EnterEmail -> SendTokenSubmitted
    EnterToken(_) -> LoginSubmitted
  }
}

fn button_text(status: Status, step: Step) -> String {
  case step, status {
    EnterEmail, SendingToken -> "Sending..."
    EnterEmail, _ -> "Send Token"
    EnterToken(_), LoggingIn -> "Logging in..."
    EnterToken(_), _ -> "Log In"
  }
}
