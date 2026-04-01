import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/types
import glot_backend/erlang

pub fn run(
  commands: List(types.Program(Nil)),
  next: fn(Result(Nil, error.DbTransactionError)) -> types.Program(a),
  handlers: runtime_types.Handlers,
  state: types.State,
  continue: fn(types.Program(a), types.State) -> #(Result(a, error.Error), types.State),
  measure: fn(types.State, types.EffectName, Int) -> types.State,
) -> #(Result(a, error.Error), types.State) {
  let started_at = erlang.perf_counter_ns()
  let transaction_result = handlers.run_in_transaction(commands)
  continue(
    next(transaction_result),
    measure(state, types.RunInTransactionEffect([]), started_at),
  )
}
