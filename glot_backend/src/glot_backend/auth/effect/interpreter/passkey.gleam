import glot_backend/auth/effect/algebra as auth_algebra
import glot_backend/auth/effect/algebra/passkey as passkey_algebra
import glot_backend/auth/ports/passkey_store.{type PasskeyStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: passkey_algebra.Effect(next_program),
  store: PasskeyStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    passkey_algebra.GetPasskeyCredentialByCredentialId(credential_id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_credential_by_credential_id(credential_id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(
                passkey_algebra.GetPasskeyCredentialByCredentialIdEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(
              passkey_algebra.GetPasskeyCredentialByCredentialIdEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    passkey_algebra.ListPasskeyCredentialsByUserId(user_id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.list_credentials_by_user_id(user_id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(
                passkey_algebra.ListPasskeyCredentialsByUserIdEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(passkey_algebra.ListPasskeyCredentialsByUserIdEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    passkey_algebra.GetPasskeyChallengeById(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_challenge_by_id(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(passkey_algebra.GetPasskeyChallengeByIdEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(passkey_algebra.GetPasskeyChallengeByIdEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    passkey_algebra.CreatePasskeyCredential(
      passkey_credential: passkey_credential,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create_credential(passkey_credential)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(passkey_algebra.CreatePasskeyCredentialEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    passkey_algebra.CreatePasskeyChallenge(
      passkey_challenge: passkey_challenge,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create_challenge(passkey_challenge)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(passkey_algebra.CreatePasskeyChallengeEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    passkey_algebra.DeletePasskeyCredential(id: id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_credential(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(passkey_algebra.DeletePasskeyCredentialEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    passkey_algebra.UpdatePasskeyCredential(
      passkey_credential: passkey_credential,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.update_credential(passkey_credential)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(passkey_algebra.UpdatePasskeyCredentialEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    passkey_algebra.DeletePasskeyChallenge(id: id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_challenge(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(passkey_algebra.DeletePasskeyChallengeEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(name: passkey_algebra.EffectName) -> effect_trace.EffectName {
  effect_trace.AuthEffectName(auth_algebra.PasskeyName(name))
}
