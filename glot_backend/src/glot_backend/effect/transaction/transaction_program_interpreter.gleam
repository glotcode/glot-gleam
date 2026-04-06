import glot_backend/context
import glot_backend/effect/db_interpreter
import glot_backend/effect/error
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime

pub fn run_with_state(
  effect: program_types.TransactionProgram(a),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
) -> #(Result(a, error.Error), program_state.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, runtime, ctx, next_state)
  }

  case effect {
    program_types.TxPure(value) -> #(Ok(value), state)
    program_types.TxFail(error) -> #(Error(error), state)
    program_types.TxImpure(effect) ->
      db_interpreter.run(effect, ctx, runtime.handlers, state, continue)
  }
}
