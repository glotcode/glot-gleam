import gleam/list
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  commands: List(effect_model.Program(Nil)),
  next: fn(Result(Nil, error.DbTransactionError)) -> effect_model.Program(a),
  handlers: handlers_types.Handlers,
  state: program_state.State,
  continue: fn(effect_model.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  let started_at = erlang.perf_counter_ns()
  let #(transaction_result, transaction_state) =
    handlers.transaction.run_in_transaction(commands)
  let nested_effects =
    transaction_state.effect_timings
    |> list.map(fn(timing) {
      timing.name
    })
  continue(
    next(transaction_result),
    program_state.measure_effect(
      state,
      effect_model.RunInTransactionEffect(nested_effects),
      effect_model.DbWriteEffectCategory,
      started_at,
    ),
  )
}
