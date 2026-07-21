import glot_core/auth/passkey_dto
import glot_core/email/email_address_model.{type EmailAddress}
import glot_frontend/api/response
import glot_frontend/ui/passkey
import lustre/effect.{type Effect}

pub type Ports(msg) {
  Ports(
    detect_passkey_support: fn(fn(Bool) -> msg) -> Effect(msg),
    send_login_token: fn(EmailAddress, fn(response.Response(Nil)) -> msg) ->
      Effect(msg),
    login: fn(EmailAddress, String, fn(response.Response(Nil)) -> msg) ->
      Effect(msg),
    begin_passkey_login: fn(
      fn(response.Response(passkey_dto.BeginPasskeyLoginResponse)) -> msg,
    ) -> Effect(msg),
    authenticate_passkey: fn(
      passkey_dto.BeginPasskeyLoginResponse,
      fn(Result(passkey.AuthenticationResult, passkey.PasskeyError)) -> msg,
    ) -> Effect(msg),
    finish_passkey_login: fn(
      passkey_dto.FinishPasskeyLoginRequest,
      fn(response.Response(Nil)) -> msg,
    ) -> Effect(msg),
    navigate_replace: fn(String) -> Effect(msg),
  )
}
