import gleam/list
import glot_frontend/public/login/message.{
  type Msg, EmailChanged, LoginSubmitted, PasskeyLoginSubmitted,
  SendTokenSubmitted, TokenChanged,
}
import glot_frontend/public/login/model.{
  type Model, type PasskeyStatus, type Status, type Step, EnterEmail, EnterToken,
  FinishingPasskey, Idle, LoggingIn, PasskeyError, PasskeyIdle, SendingToken,
  StartingPasskey, StatusError, StatusInfo, WaitingForPasskey,
}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn view(model: Model) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main(
      [
        attribute.id("main-content"),
        attribute.attribute("tabindex", "-1"),
        attribute.class("app-shell app-shell--narrow"),
      ],
      [
        html.div([attribute.class("login-page__sections")], [
          intro_section(),
          email_section(model),
          case show_passkey_section(model.passkey_supported) {
            True -> passkey_section(model)
            False -> html.text("")
          },
        ]),
      ],
    ),
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
    html.h2([attribute.class("login-page__section-title")], [
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
    html.h2([attribute.class("login-page__section-title")], [
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
      attribute.autocomplete("email"),
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
    SendingToken -> info_status("Sending login email...")
    LoggingIn -> info_status("Logging in...")
    StatusInfo(message) -> info_status(message)
    StatusError(message) -> error_status(message)
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
    StartingPasskey -> info_status("Preparing passkey login...")
    WaitingForPasskey ->
      info_status("Complete the passkey prompt from your browser or device.")
    FinishingPasskey -> info_status("Logging in with passkey...")
    PasskeyError(message) -> error_status(message)
  }
}

fn info_status(message: String) -> Element(Msg) {
  html.p(
    [
      attribute.class("login-page__status"),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [html.text(message)],
  )
}

fn error_status(message: String) -> Element(Msg) {
  html.p(
    [
      attribute.class("login-page__status login-page__status--error"),
      attribute.attribute("role", "alert"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [html.text(message)],
  )
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

fn token_disabled(model: Model) -> Bool {
  case model.step {
    EnterToken(_) -> is_busy(model.status, model.passkey_status)
    EnterEmail -> True
  }
}
