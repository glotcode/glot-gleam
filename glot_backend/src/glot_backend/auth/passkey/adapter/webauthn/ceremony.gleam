import glot_backend/auth/passkey/adapter/webauthn/ffi
import glot_backend/auth/passkey/ports/ceremony.{type Ceremony}

pub fn new() -> Ceremony {
  ceremony.Ceremony(
    new_registration_challenge: ffi.new_registration_challenge,
    register: ffi.register,
    new_authentication_challenge: ffi.new_authentication_challenge,
    authenticate: ffi.authenticate,
  )
}
