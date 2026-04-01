import gleam/list
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers_types
import glot_backend/erlang

pub fn run(
  commands: List(effect_model.Program(Nil)),
  next: fn(Result(Nil, error.DbTransactionError)) -> effect_model.Program(a),
  handlers: handlers_types.Handlers,
  state: effect_model.State,
  continue: fn(effect_model.Program(a), effect_model.State) -> #(Result(a, error.Error), effect_model.State),
  measure: fn(effect_model.State, effect_model.EffectName, Int) -> effect_model.State,
) -> #(Result(a, error.Error), effect_model.State) {
  let started_at = erlang.perf_counter_ns()
  let #(transaction_result, transaction_state) =
    handlers.transaction.run_in_transaction(commands)
  let nested_effects =
    transaction_state.effect_timings
    |> list.map(fn(timing) {
      let #(effect_name, _) = timing
      effect_name
    })
  continue(
    next(transaction_result),
    measure(
      state,
      effect_model.RunInTransactionEffect(nested_effects),
      started_at,
    ),
  )
}
