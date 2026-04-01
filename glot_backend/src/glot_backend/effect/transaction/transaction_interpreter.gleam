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
  let transaction_result = handlers.run_in_transaction(commands)
  continue(
    next(transaction_result),
    measure(state, effect_model.RunInTransactionEffect([]), started_at),
  )
}
