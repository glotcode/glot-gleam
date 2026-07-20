import glot_backend/system/effect/db_interpreter
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/effect/program_types
import glot_backend/system/effect/runtime
import glot_backend/system/request/context

pub fn run_with_state(
  effect: program_types.TransactionProgram(a),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
) -> #(Result(a, error.Error), program_state.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, runtime, ctx, next_state)
  }
  let effect_runtime =
    runtime.with_timeout(runtime, context.remaining_timeout_ms(ctx))

  case effect {
    program_types.TxPure(value) -> #(Ok(value), state)
    program_types.TxFail(error) -> #(Error(error), state)
    program_types.TxImpure(effect) ->
      db_interpreter.run(
        effect,
        ctx,
        effect_runtime.services.database,
        state,
        continue,
      )
  }
}
