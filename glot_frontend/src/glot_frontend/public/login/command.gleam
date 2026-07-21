import glot_core/auth/passkey_dto
import glot_core/email/email_address_model.{type EmailAddress}
import glot_frontend/api/response
import glot_frontend/ui/passkey

pub type Command(msg) {
  None
  DetectPasskeySupport(fn(Bool) -> msg)
  SendLoginToken(EmailAddress, fn(response.Response(Nil)) -> msg)
  Login(EmailAddress, String, fn(response.Response(Nil)) -> msg)
  BeginPasskeyLogin(
    fn(response.Response(passkey_dto.BeginPasskeyLoginResponse)) -> msg,
  )
  AuthenticatePasskey(
    passkey_dto.BeginPasskeyLoginResponse,
    fn(Result(passkey.AuthenticationResult, passkey.PasskeyError)) -> msg,
  )
  FinishPasskeyLogin(
    passkey_dto.FinishPasskeyLoginRequest,
    fn(response.Response(Nil)) -> msg,
  )
  NavigateReplace(String)
}

pub fn none() -> Command(msg) {
  None
}
