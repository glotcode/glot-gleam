import gleam/list
import gleam/option
import gleam/regexp
import gleam/string
import glot_core/auth/passkey_dto
import glot_core/email/email_address_model
import glot_core/route
import glot_frontend/api
import glot_frontend/app_event
import glot_frontend/passkey
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import youid/uuid

pub type Model {
  Model(
    email: String,
    token: String,
    step: Step,
    status: Status,
    passkey_supported: Bool,
    passkey_challenge_id: option.Option(uuid.Uuid),
    passkey_status: PasskeyStatus,
  )
}

pub type Step {
  EnterEmail
  EnterToken(email: email_address_model.EmailAddress)
}

pub type Status {
  Idle
  SendingToken
  LoggingIn
  StatusInfo(message: String)
  StatusError(message: String)
}

pub type PasskeyStatus {
  PasskeyIdle
  StartingPasskey
  WaitingForPasskey
  FinishingPasskey
  PasskeyError(message: String)
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      email: "",
      token: "",
      step: EnterEmail,
      status: Idle,
      passkey_supported: passkey.is_supported(),
      passkey_challenge_id: option.None,
      passkey_status: PasskeyIdle,
    ),
    effect.none(),
  )
}

pub type Msg {
  EmailChanged(String)
  TokenChanged(String)
  SendTokenSubmitted
  LoginSubmitted
  PasskeyLoginSubmitted
  LoginTokenSent(api.ApiResponse(Nil))
  LoggedIn(api.ApiResponse(Nil))
  BeganPasskeyLogin(api.ApiResponse(passkey_dto.BeginPasskeyLoginResponse))
  CompletedPasskeyLogin(
    Result(passkey.AuthenticationResult, passkey.PasskeyError),
  )
  FinishedPasskeyLogin(api.ApiResponse(Nil))
}

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg), app_event.AppEvent) {
  case msg {
    EmailChanged(email) -> {
      #(
        Model(
          email: email,
          token: "",
          step: EnterEmail,
          status: Idle,
          passkey_supported: model.passkey_supported,
          passkey_challenge_id: option.None,
          passkey_status: PasskeyIdle,
        ),
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
              status: StatusError("Please enter a valid email address."),
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
                Model(
                  ..model,
                  status: StatusError("Please enter the login token."),
                ),
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

    PasskeyLoginSubmitted -> {
      #(
        Model(
          ..model,
          passkey_challenge_id: option.None,
          passkey_status: StartingPasskey,
        ),
        api.begin_passkey_login(BeganPasskeyLogin),
        app_event.NoAppEvent,
      )
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
              status: StatusInfo("A login token has been sent to your email."),
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
              status: StatusError("Please enter a valid email address."),
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
              status: StatusError(api.error_message(error)),
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
              status: StatusError("Could not send login email."),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }
      }
    }

    LoggedIn(result) -> finish_login_response(model, result)

    BeganPasskeyLogin(result) -> {
      case result {
        api.ApiSuccess(response) -> {
          #(
            Model(
              ..model,
              passkey_challenge_id: option.Some(response.challenge_id),
              passkey_status: WaitingForPasskey,
            ),
            passkey.begin_authentication(response, CompletedPasskeyLogin),
            app_event.NoAppEvent,
          )
        }

        api.ApiFailure(error) -> {
          #(
            Model(
              ..model,
              passkey_status: PasskeyError(api.error_message(error)),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }

        api.HttpFailure(_) -> {
          #(
            Model(
              ..model,
              passkey_status: PasskeyError("Could not start passkey login."),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }
      }
    }

    CompletedPasskeyLogin(result) -> {
      case result {
        Ok(authentication_result) -> {
          case model.passkey_challenge_id {
            option.Some(challenge_id) -> {
              let request =
                passkey_dto.FinishPasskeyLoginRequest(
                  challenge_id: challenge_id,
                  credential_id: authentication_result.credential_id,
                  authenticator_data: authentication_result.authenticator_data,
                  signature: authentication_result.signature,
                  client_data_json: authentication_result.client_data_json,
                )

              #(
                Model(..model, passkey_status: FinishingPasskey),
                api.finish_passkey_login(request, FinishedPasskeyLogin),
                app_event.NoAppEvent,
              )
            }

            option.None -> {
              #(
                Model(
                  ..model,
                  passkey_status: PasskeyError(
                    "Could not complete passkey login.",
                  ),
                ),
                effect.none(),
                app_event.NoAppEvent,
              )
            }
          }
        }

        Error(error) -> {
          #(
            Model(
              ..model,
              passkey_status: PasskeyError(passkey.error_message(error)),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }
      }
    }

    FinishedPasskeyLogin(result) -> finish_passkey_login_response(model, result)
  }
}

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell app-shell--narrow")], [
      html.div([attribute.class("login-page__sections")], [
        intro_section(),
        email_section(model),
        case show_passkey_section(model.passkey_supported) {
          True -> passkey_section(model)
          False -> html.text("")
        },
      ]),
    ]),
  ])
}

fn intro_section() -> Element(Msg) {
  html.section([attribute.class("app-panel login-page__section")], [
    html.h1([attribute.class("login-page__title")], [html.text("Login")]),
    html.p([attribute.class("login-page__section-copy")], [
      html.text(
        "No account yet? An account will be created when you log in with email for the first time.",
      ),
    ]),
  ])
}

fn passkey_section(model: Model) -> Element(Msg) {
  html.section([attribute.class("app-panel login-page__section")], [
    html.h3([attribute.class("login-page__section-title")], [
      html.text("Login by passkey"),
    ]),
    html.p([attribute.class("login-page__section-copy")], [
      html.text(
        "Use a saved passkey from your browser, password manager, or device.",
      ),
    ]),
    passkey_status_view(model.passkey_status),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(is_busy(model.status, model.passkey_status)),
        attribute.class("login-page__button"),
        event.on_click(PasskeyLoginSubmitted),
      ],
      [html.text(passkey_button_text(model.passkey_status))],
    ),
  ])
}

fn email_section(model: Model) -> Element(Msg) {
  html.section([attribute.class("app-panel login-page__section")], [
    html.h3([attribute.class("login-page__section-title")], [
      html.text("Login by email"),
    ]),
    html.p([attribute.class("login-page__section-copy")], [
      html.text("We’ll email you a one-time token. No password required."),
    ]),
    html.form(
      [
        event.on_submit(fn(_) { email_submit_msg(model.step) }),
        attribute.class("login-page__form"),
      ],
      email_fields(model),
    ),
  ])
}

fn email_fields(model: Model) -> List(Element(Msg)) {
  let token_elements = case model.step {
    EnterToken(_) -> token_fields(model)
    EnterEmail -> []
  }

  let email_button = case show_send_token_button(model.step) {
    True -> [
      html.button(
        [
          attribute.type_("submit"),
          attribute.disabled(is_busy(model.status, model.passkey_status)),
          attribute.class("login-page__button"),
        ],
        [html.text(email_button_text(model.status))],
      ),
    ]

    False -> []
  }

  [
    html.label([attribute.for("email"), attribute.class("login-page__label")], [
      html.text("Email"),
    ]),
    html.input([
      attribute.id("email"),
      attribute.name("email"),
      attribute.type_("email"),
      attribute.placeholder("you@example.com"),
      attribute.value(model.email),
      event.on_input(EmailChanged),
      attribute.disabled(is_busy(model.status, model.passkey_status)),
      attribute.class("login-page__input"),
    ]),
    email_status_view(model.status, model.step),
  ]
  |> list.append(email_button)
  |> list.append(token_elements)
}

fn token_fields(model: Model) -> List(Element(Msg)) {
  [
    token_status_view(model.status),
    html.label([attribute.for("token"), attribute.class("login-page__label")], [
      html.text("Token"),
    ]),
    html.input([
      attribute.id("token"),
      attribute.name("token"),
      attribute.type_("text"),
      attribute.autocomplete("one-time-code"),
      attribute.placeholder("Enter login token"),
      attribute.value(model.token),
      event.on_input(TokenChanged),
      attribute.disabled(token_disabled(model)),
      attribute.class("login-page__input"),
    ]),
    html.button(
      [
        attribute.type_("submit"),
        attribute.disabled(token_disabled(model)),
        attribute.class("login-page__button"),
      ],
      [html.text(token_button_text(model.status))],
    ),
  ]
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
    StatusInfo(message) ->
      html.p([attribute.class("login-page__status")], [
        html.text(message),
      ])
    StatusError(message) ->
      html.p([attribute.class("login-page__status login-page__status--error")], [
        html.text(message),
      ])
  }
}

fn email_status_view(status: Status, step: Step) -> Element(Msg) {
  case step, status {
    EnterEmail, SendingToken | EnterEmail, StatusError(_) -> status_view(status)
    _, _ -> html.text("")
  }
}

fn token_status_view(status: Status) -> Element(Msg) {
  case status {
    StatusInfo(_) | LoggingIn | StatusError(_) -> status_view(status)
    _ -> html.text("")
  }
}

fn passkey_status_view(passkey_status: PasskeyStatus) -> Element(Msg) {
  case passkey_status {
    PasskeyIdle -> html.text("")
    StartingPasskey ->
      html.p([attribute.class("login-page__status")], [
        html.text("Preparing passkey login..."),
      ])
    WaitingForPasskey ->
      html.p([attribute.class("login-page__status")], [
        html.text("Complete the passkey prompt from your browser or device."),
      ])
    FinishingPasskey ->
      html.p([attribute.class("login-page__status")], [
        html.text("Logging in with passkey..."),
      ])
    PasskeyError(message) ->
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

fn is_submitting_passkey(passkey_status: PasskeyStatus) -> Bool {
  case passkey_status {
    StartingPasskey | WaitingForPasskey | FinishingPasskey -> True
    _ -> False
  }
}

fn is_busy(status: Status, passkey_status: PasskeyStatus) -> Bool {
  is_submitting(status) || is_submitting_passkey(passkey_status)
}

fn email_button_text(status: Status) -> String {
  case status {
    SendingToken -> "Sending..."
    _ -> "Send token"
  }
}

pub fn email_submit_msg(step: Step) -> Msg {
  case step {
    EnterEmail -> SendTokenSubmitted
    EnterToken(_) -> LoginSubmitted
  }
}

pub fn show_send_token_button(step: Step) -> Bool {
  case step {
    EnterEmail -> True
    EnterToken(_) -> False
  }
}

pub fn show_passkey_section(passkey_supported: Bool) -> Bool {
  passkey_supported
}

fn token_button_text(status: Status) -> String {
  case status {
    LoggingIn -> "Logging in..."
    _ -> "Log in"
  }
}

fn passkey_button_text(passkey_status: PasskeyStatus) -> String {
  case passkey_status {
    StartingPasskey -> "Preparing..."
    WaitingForPasskey -> "Waiting for passkey..."
    FinishingPasskey -> "Logging in..."
    _ -> "Log in with passkey"
  }
}

fn finish_login_response(
  model: Model,
  result: api.ApiResponse(Nil),
) -> #(Model, Effect(Msg), app_event.AppEvent) {
  case result {
    api.ApiSuccess(_) -> login_succeeded(model)
    api.ApiFailure(error) -> {
      #(
        Model(..model, status: StatusError(api.error_message(error))),
        effect.none(),
        app_event.NoAppEvent,
      )
    }
    api.HttpFailure(_) -> {
      #(
        Model(..model, status: StatusError("Could not complete login.")),
        effect.none(),
        app_event.NoAppEvent,
      )
    }
  }
}

fn finish_passkey_login_response(
  model: Model,
  result: api.ApiResponse(Nil),
) -> #(Model, Effect(Msg), app_event.AppEvent) {
  case result {
    api.ApiSuccess(_) -> login_succeeded(model)
    api.ApiFailure(error) -> {
      #(
        Model(..model, passkey_status: PasskeyError(api.error_message(error))),
        effect.none(),
        app_event.NoAppEvent,
      )
    }
    api.HttpFailure(_) -> {
      #(
        Model(
          ..model,
          passkey_status: PasskeyError("Could not complete passkey login."),
        ),
        effect.none(),
        app_event.NoAppEvent,
      )
    }
  }
}

fn login_succeeded(model: Model) -> #(Model, Effect(Msg), app_event.AppEvent) {
  #(
    Model(
      ..model,
      status: StatusInfo("You are now logged in."),
      passkey_challenge_id: option.None,
      passkey_status: PasskeyIdle,
    ),
    modem.replace(
      route.to_string(route.Public(route.Home)),
      option.None,
      option.None,
    ),
    app_event.RefreshSession,
  )
}

fn token_disabled(model: Model) -> Bool {
  case model.step {
    EnterToken(_) -> is_busy(model.status, model.passkey_status)
    EnterEmail -> True
  }
}
