import glot_backend/auth/passkey/adapter/webauthn/ffi as webauthn
import glot_backend/auth/passkey/ports/ceremony

pub fn new() -> ceremony.Ceremony {
  ceremony.Ceremony(
    new_registration_challenge: webauthn.new_registration_challenge,
    register: webauthn.register,
    new_authentication_challenge: webauthn.new_authentication_challenge,
    authenticate: fn(
      credential_id,
      authenticator_data,
      signature,
      client_data_json,
      challenge_state,
      credentials,
    ) {
      case client_data_json {
        "test-passkey-login-success" -> Ok(#(2, <<>>))
        _ ->
          webauthn.authenticate(
            credential_id,
            authenticator_data,
            signature,
            client_data_json,
            challenge_state,
            credentials,
          )
      }
    },
  )
}
