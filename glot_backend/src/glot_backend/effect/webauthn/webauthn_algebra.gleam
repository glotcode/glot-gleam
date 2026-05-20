pub type WebauthnEffect(next) {
  NewRegistrationChallenge(
    origin: String,
    rp_id: String,
    user_verification: String,
    next: fn(Result(#(String, BitArray), String)) -> next,
  )
  Register(
    attestation_object: BitArray,
    client_data_json: String,
    challenge_state: BitArray,
    next: fn(Result(#(BitArray, BitArray, Int, BitArray), String)) -> next,
  )
  NewAuthenticationChallenge(
    origin: String,
    rp_id: String,
    user_verification: String,
    credentials: List(#(BitArray, BitArray)),
    next: fn(Result(#(String, List(String), BitArray), String)) -> next,
  )
  Authenticate(
    credential_id: BitArray,
    authenticator_data: BitArray,
    signature: BitArray,
    client_data_json: String,
    challenge_state: BitArray,
    credentials: List(#(BitArray, BitArray)),
    next: fn(Result(#(Int, BitArray), String)) -> next,
  )
}

pub fn map(effect: WebauthnEffect(a), f: fn(a) -> b) -> WebauthnEffect(b) {
  case effect {
    NewRegistrationChallenge(origin, rp_id, user_verification, next) ->
      NewRegistrationChallenge(origin, rp_id, user_verification, fn(value) {
        f(next(value))
      })
    Register(attestation_object, client_data_json, challenge_state, next) ->
      Register(attestation_object, client_data_json, challenge_state, fn(value) {
        f(next(value))
      })
    NewAuthenticationChallenge(
      origin,
      rp_id,
      user_verification,
      credentials,
      next,
    ) ->
      NewAuthenticationChallenge(
        origin,
        rp_id,
        user_verification,
        credentials,
        fn(value) { f(next(value)) },
      )
    Authenticate(
      credential_id,
      authenticator_data,
      signature,
      client_data_json,
      challenge_state,
      credentials,
      next,
    ) ->
      Authenticate(
        credential_id,
        authenticator_data,
        signature,
        client_data_json,
        challenge_state,
        credentials,
        fn(value) { f(next(value)) },
      )
  }
}

pub type EffectName {
  NewRegistrationChallengeEffectName
  RegisterEffectName
  NewAuthenticationChallengeEffectName
  AuthenticateEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    NewRegistrationChallengeEffectName -> "new_registration_challenge"
    RegisterEffectName -> "register"
    NewAuthenticationChallengeEffectName -> "new_authentication_challenge"
    AuthenticateEffectName -> "authenticate"
  }
}
