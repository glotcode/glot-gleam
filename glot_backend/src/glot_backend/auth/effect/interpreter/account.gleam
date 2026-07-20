import glot_backend/auth/effect/algebra as auth_algebra
import glot_backend/auth/effect/algebra/account as account_algebra
import glot_backend/auth/ports/account_store.{type AccountStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang

pub fn run(
  effect: account_algebra.Effect(next_program),
  store: AccountStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    account_algebra.CreateAccount(account: account, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create(account)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(account_algebra.CreateAccountEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    account_algebra.UpdateAccount(account: account, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.update(account)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(account_algebra.UpdateAccountEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    account_algebra.DeleteAccount(account_id: account_id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete(account_id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(account_algebra.DeleteAccountEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(name: account_algebra.EffectName) -> effect_trace.EffectName {
  effect_trace.AuthEffectName(auth_algebra.AccountName(name))
}
