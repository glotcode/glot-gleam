import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  sub_effects: List(effect_model.Program(Nil)),
  next: fn(Result(Nil, error.DbTransactionError)) -> effect_model.Program(a),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(effect_model.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  let started_at = erlang.perf_counter_ns()
  let #(transaction_result, transaction_state) =
    handlers.transaction.run_in_transaction(sub_effects)
  continue(
    next(transaction_result),
    program_state.add_effect_measurement(
      state,
      effect_model.RunInTransactionEffectName(
        transaction_state.effect_measurements,
      ),
      effect_model.DbWriteEffectCategory,
      started_at,
    ),
  )
}
