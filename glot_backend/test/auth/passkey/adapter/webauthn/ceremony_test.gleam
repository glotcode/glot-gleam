import gleam/bit_array
import glot_backend/auth/passkey/adapter/webauthn/ffi as webauthn

pub fn new_registration_challenge_returns_challenge_and_state_test() {
  let assert Ok(#(challenge, state)) =
    webauthn.new_registration_challenge(
      "https://www.example.com",
      "example.com",
      "required",
    )

  assert challenge != ""
  assert bit_array.byte_size(state) > 0
}

pub fn new_authentication_challenge_returns_challenge_and_state_test() {
  let assert Ok(#(challenge, allow_credential_ids, state)) =
    webauthn.new_authentication_challenge(
      "https://www.example.com",
      "example.com",
      "required",
      [],
    )

  assert challenge != ""
  assert allow_credential_ids == []
  assert bit_array.byte_size(state) > 0
}
