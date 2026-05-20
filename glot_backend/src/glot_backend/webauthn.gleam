@external(erlang, "webauthn_ffi", "new_registration_challenge")
pub fn new_registration_challenge(
  _origin: String,
  _rp_id: String,
  _user_verification: String,
) -> Result(#(String, BitArray), String) {
  panic as "not implemented"
}

@external(erlang, "webauthn_ffi", "register")
pub fn register(
  _attestation_object: BitArray,
  _client_data_json: String,
  _challenge_state: BitArray,
) -> Result(#(BitArray, BitArray, Int, BitArray), String) {
  panic as "not implemented"
}

@external(erlang, "webauthn_ffi", "new_authentication_challenge")
pub fn new_authentication_challenge(
  _origin: String,
  _rp_id: String,
  _user_verification: String,
  _credentials: List(#(BitArray, BitArray)),
) -> Result(#(String, List(String), BitArray), String) {
  panic as "not implemented"
}

@external(erlang, "webauthn_ffi", "authenticate")
pub fn authenticate(
  _credential_id: BitArray,
  _authenticator_data: BitArray,
  _signature: BitArray,
  _client_data_json: String,
  _challenge_state: BitArray,
  _credentials: List(#(BitArray, BitArray)),
) -> Result(#(Int, BitArray), String) {
  panic as "not implemented"
}
