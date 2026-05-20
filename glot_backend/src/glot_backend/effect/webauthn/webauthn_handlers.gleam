import glot_backend/webauthn

pub type WebauthnHandlers {
  WebauthnHandlers(
    new_registration_challenge: fn(String, String, String) ->
      Result(#(String, BitArray), String),
    register: fn(BitArray, String, BitArray) ->
      Result(#(BitArray, BitArray, Int, BitArray), String),
    new_authentication_challenge: fn(
      String,
      String,
      String,
      List(#(BitArray, BitArray)),
    ) -> Result(#(String, List(String), BitArray), String),
    authenticate: fn(
      BitArray,
      BitArray,
      BitArray,
      String,
      BitArray,
      List(#(BitArray, BitArray)),
    ) -> Result(#(Int, BitArray), String),
  )
}

pub fn new() -> WebauthnHandlers {
  WebauthnHandlers(
    new_registration_challenge: webauthn.new_registration_challenge,
    register: webauthn.register,
    new_authentication_challenge: webauthn.new_authentication_challenge,
    authenticate: webauthn.authenticate,
  )
}
