import glot_backend/effect/program_types
import glot_backend/effect/webauthn/webauthn_algebra

pub fn new_registration_challenge(
  origin: String,
  rp_id: String,
  user_verification: String,
) -> program_types.Program(Result(#(String, BitArray), String)) {
  program_types.Impure(
    program_types.WebauthnEffect(webauthn_algebra.NewRegistrationChallenge(
      origin,
      rp_id,
      user_verification,
      program_types.Pure,
    )),
  )
}

pub fn register(
  attestation_object: BitArray,
  client_data_json: String,
  challenge_state: BitArray,
) -> program_types.Program(Result(#(BitArray, BitArray, Int, BitArray), String)) {
  program_types.Impure(
    program_types.WebauthnEffect(webauthn_algebra.Register(
      attestation_object,
      client_data_json,
      challenge_state,
      program_types.Pure,
    )),
  )
}

pub fn new_authentication_challenge(
  origin: String,
  rp_id: String,
  user_verification: String,
  credentials: List(#(BitArray, BitArray)),
) -> program_types.Program(Result(#(String, List(String), BitArray), String)) {
  program_types.Impure(
    program_types.WebauthnEffect(webauthn_algebra.NewAuthenticationChallenge(
      origin,
      rp_id,
      user_verification,
      credentials,
      program_types.Pure,
    )),
  )
}

pub fn authenticate(
  credential_id: BitArray,
  authenticator_data: BitArray,
  signature: BitArray,
  client_data_json: String,
  challenge_state: BitArray,
  credentials: List(#(BitArray, BitArray)),
) -> program_types.Program(Result(#(Int, BitArray), String)) {
  program_types.Impure(
    program_types.WebauthnEffect(webauthn_algebra.Authenticate(
      credential_id,
      authenticator_data,
      signature,
      client_data_json,
      challenge_state,
      credentials,
      program_types.Pure,
    )),
  )
}
