import glot_core/auth/passkey_dto
import glot_frontend/api/response
import glot_frontend/ui/passkey

pub type Msg {
  PasskeySupportDetected(Bool)
  EmailChanged(String)
  TokenChanged(String)
  SendTokenSubmitted
  LoginSubmitted
  PasskeyLoginSubmitted
  LoginTokenSent(response.Response(Nil))
  LoggedIn(response.Response(Nil))
  BeganPasskeyLogin(response.Response(passkey_dto.BeginPasskeyLoginResponse))
  CompletedPasskeyLogin(
    Result(passkey.AuthenticationResult, passkey.PasskeyError),
  )
  FinishedPasskeyLogin(response.Response(Nil))
}
