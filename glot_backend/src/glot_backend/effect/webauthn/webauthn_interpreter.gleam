import glot_backend/context
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/effect/webauthn/webauthn_algebra
import glot_backend/erlang

pub fn run(
  effect: webauthn_algebra.WebauthnEffect(program_types.Program(a)),
  runtime: runtime.Runtime,
  _ctx: context.Context,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    webauthn_algebra.NewRegistrationChallenge(
      origin,
      rp_id,
      user_verification,
      next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.webauthn.new_registration_challenge(
          origin,
          rp_id,
          user_verification,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.WebauthnEffectName(
            webauthn_algebra.NewRegistrationChallengeEffectName,
          ),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    webauthn_algebra.Register(
      attestation_object,
      client_data_json,
      challenge_state,
      next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.webauthn.register(
          attestation_object,
          client_data_json,
          challenge_state,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.WebauthnEffectName(webauthn_algebra.RegisterEffectName),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    webauthn_algebra.NewAuthenticationChallenge(
      origin,
      rp_id,
      user_verification,
      credentials,
      next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.webauthn.new_authentication_challenge(
          origin,
          rp_id,
          user_verification,
          credentials,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.WebauthnEffectName(
            webauthn_algebra.NewAuthenticationChallengeEffectName,
          ),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
    webauthn_algebra.Authenticate(
      credential_id,
      authenticator_data,
      signature,
      client_data_json,
      challenge_state,
      credentials,
      next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.webauthn.authenticate(
          credential_id,
          authenticator_data,
          signature,
          client_data_json,
          challenge_state,
          credentials,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.WebauthnEffectName(
            webauthn_algebra.AuthenticateEffectName,
          ),
          effect_trace.UtilEffectCategory,
          started_at,
        ),
      )
    }
  }
}
