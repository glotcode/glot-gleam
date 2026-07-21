import gleam/option
import glot_frontend/app/event as app_event
import glot_frontend/public/login/command
import glot_frontend/public/login/email_update
import glot_frontend/public/login/message.{
  type Msg, BeganPasskeyLogin, CompletedPasskeyLogin, EmailChanged,
  FinishedPasskeyLogin, LoggedIn, LoginSubmitted, LoginTokenSent,
  PasskeyLoginSubmitted, PasskeySupportDetected, SendTokenSubmitted,
  TokenChanged,
}
import glot_frontend/public/login/model.{
  type Model, EnterEmail, Idle, PasskeyIdle,
}
import glot_frontend/public/login/passkey_update

pub fn init() -> #(Model, command.Command(Msg)) {
  #(
    model.Model(
      email: "",
      token: "",
      step: EnterEmail,
      status: Idle,
      passkey_supported: False,
      passkey_challenge_id: option.None,
      passkey_status: PasskeyIdle,
    ),
    command.DetectPasskeySupport(PasskeySupportDetected),
  )
}

pub fn update(model: Model, msg: Msg) {
  case msg {
    PasskeySupportDetected(supported) -> #(
      model.Model(..model, passkey_supported: supported),
      command.none(),
      app_event.NoAppEvent,
    )
    EmailChanged(_)
    | TokenChanged(_)
    | SendTokenSubmitted
    | LoginSubmitted
    | LoginTokenSent(_)
    | LoggedIn(_) -> email_update.update(model, msg)
    PasskeyLoginSubmitted
    | BeganPasskeyLogin(_)
    | CompletedPasskeyLogin(_)
    | FinishedPasskeyLogin(_) -> passkey_update.update(model, msg)
  }
}
