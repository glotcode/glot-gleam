import glot_backend/auth/passkey/effect/algebra
import glot_backend/auth/passkey/ports/ceremony.{type Ceremony}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/effect/program_types
import glot_backend/system/runtime/erlang

pub fn run(
  effect: algebra.WebauthnEffect(program_types.Program(a)),
  ceremony: Ceremony,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    algebra.NewRegistrationChallenge(origin, rp_id, user_verification, next) ->
      continue_with_measurement(
        fn() {
          ceremony.new_registration_challenge(origin, rp_id, user_verification)
        },
        next,
        algebra.NewRegistrationChallengeEffectName,
        state,
        continue,
      )
    algebra.Register(
      attestation_object,
      client_data_json,
      challenge_state,
      next,
    ) ->
      continue_with_measurement(
        fn() {
          ceremony.register(
            attestation_object,
            client_data_json,
            challenge_state,
          )
        },
        next,
        algebra.RegisterEffectName,
        state,
        continue,
      )
    algebra.NewAuthenticationChallenge(
      origin,
      rp_id,
      user_verification,
      credentials,
      next,
    ) ->
      continue_with_measurement(
        fn() {
          ceremony.new_authentication_challenge(
            origin,
            rp_id,
            user_verification,
            credentials,
          )
        },
        next,
        algebra.NewAuthenticationChallengeEffectName,
        state,
        continue,
      )
    algebra.Authenticate(
      credential_id,
      authenticator_data,
      signature,
      client_data_json,
      challenge_state,
      credentials,
      next,
    ) ->
      continue_with_measurement(
        fn() {
          ceremony.authenticate(
            credential_id,
            authenticator_data,
            signature,
            client_data_json,
            challenge_state,
            credentials,
          )
        },
        next,
        algebra.AuthenticateEffectName,
        state,
        continue,
      )
  }
}

fn continue_with_measurement(
  operation: fn() -> Result(value, String),
  next: fn(Result(value, String)) -> program_types.Program(a),
  effect_name: algebra.EffectName,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  let started_at = erlang.perf_counter_ns()
  let result = operation()
  continue(
    next(result),
    program_state.add_effect_measurement(
      state,
      effect_trace.WebauthnEffectName(effect_name),
      effect_trace.RuntimeEffect,
      started_at,
    ),
  )
}
