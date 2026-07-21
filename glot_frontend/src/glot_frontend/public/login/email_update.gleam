import gleam/option
import gleam/regexp
import gleam/string
import glot_core/email/email_address_model
import glot_frontend/api/response as api_response
import glot_frontend/app/event as app_event
import glot_frontend/public/login/command
import glot_frontend/public/login/message.{
  EmailChanged, LoggedIn, LoginSubmitted, LoginTokenSent, SendTokenSubmitted,
  TokenChanged,
}
import glot_frontend/public/login/model.{
  type Model, EnterEmail, EnterToken, Idle, LoggingIn, PasskeyIdle, SendingToken,
  StatusError, StatusInfo,
}
import glot_frontend/public/login/success

pub fn update(model: Model, msg: message.Msg) {
  case msg {
    EmailChanged(email) -> #(
      model.Model(
        email:,
        token: "",
        step: EnterEmail,
        status: Idle,
        passkey_supported: model.passkey_supported,
        passkey_challenge_id: option.None,
        passkey_status: PasskeyIdle,
      ),
      command.none(),
      app_event.NoAppEvent,
    )
    TokenChanged(token) -> #(
      model.Model(..model, token:, status: Idle),
      command.none(),
      app_event.NoAppEvent,
    )
    SendTokenSubmitted -> send_token(model)
    LoginSubmitted -> login(model)
    LoginTokenSent(result) -> token_sent(model, result)
    LoggedIn(result) -> finish(model, result)
    _ -> #(model, command.none(), app_event.NoAppEvent)
  }
}

fn send_token(model: Model) {
  let assert Ok(pattern) = regexp.from_string(email_address_model.pattern)
  case email_address_model.from_string(pattern, model.email) {
    option.Some(email) -> #(
      model.Model(..model, step: EnterEmail, status: SendingToken),
      command.SendLoginToken(email, LoginTokenSent),
      app_event.NoAppEvent,
    )
    option.None ->
      error(model, EnterEmail, "Please enter a valid email address.")
  }
}

fn login(model: Model) {
  case model.step {
    EnterEmail -> #(model, command.none(), app_event.NoAppEvent)
    EnterToken(email) ->
      case string.trim(model.token) {
        "" -> error(model, model.step, "Please enter the login token.")
        token -> #(
          model.Model(..model, status: LoggingIn),
          command.Login(email, token, LoggedIn),
          app_event.NoAppEvent,
        )
      }
  }
}

fn token_sent(model: Model, result: api_response.Response(Nil)) {
  let assert Ok(pattern) = regexp.from_string(email_address_model.pattern)
  case result, email_address_model.from_string(pattern, model.email) {
    api_response.Success(_), option.Some(email) -> #(
      model.Model(
        ..model,
        step: EnterToken(email),
        token: "",
        status: StatusInfo("A login token has been sent to your email."),
      ),
      command.none(),
      app_event.NoAppEvent,
    )
    api_response.Success(_), option.None ->
      error(model, EnterEmail, "Please enter a valid email address.")
    api_response.ApiFailure(failure), _ ->
      error(model, EnterEmail, api_response.error_message(failure))
    api_response.HttpFailure(_), _ ->
      error(model, EnterEmail, "Could not send login email.")
  }
}

fn finish(model: Model, result: api_response.Response(Nil)) {
  case result {
    api_response.Success(_) -> success.login_succeeded(model)
    api_response.ApiFailure(failure) ->
      error(model, model.step, api_response.error_message(failure))
    api_response.HttpFailure(_) ->
      error(model, model.step, "Could not complete login.")
  }
}

fn error(model: Model, step, message: String) {
  #(
    model.Model(..model, step:, status: StatusError(message)),
    command.none(),
    app_event.NoAppEvent,
  )
}
