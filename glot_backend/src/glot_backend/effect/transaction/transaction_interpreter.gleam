import gleam/list
import gleam/string
import glot_backend/context
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/effect/transaction/transaction_algebra
import glot_backend/effect/transaction/transaction_handlers
import glot_backend/effect/transaction/transaction_program_interpreter
import glot_backend/erlang
import pog

pub fn run(
  effect: program_types.TransactionEffect(program_types.Program(a)),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    program_types.Run(program:) -> {
      let started_at = erlang.perf_counter_ns()
      let #(transaction_result, transaction_state) =
        run_in_transaction(runtime, ctx, program)

      let next_state =
        program_state.add_effect_measurement(
          state,
          effect_trace.TransactionEffectName(
            transaction_algebra.RunEffectName,
            transaction_state.effect_measurements,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        )

      case transaction_result {
        Ok(value) -> continue(value, next_state)
        Error(err) -> #(Error(error.TransactionError(err)), next_state)
      }
    }
  }
}

fn run_in_transaction(
  runtime: runtime.Runtime,
  ctx: context.Context,
  program: program_types.TransactionProgram(program_types.Program(a)),
) -> #(
  Result(program_types.Program(a), error.DbTransactionError),
  program_state.State,
) {
  transaction_handlers.run(runtime.handlers.transaction, fn(tx) {
    let transaction_runtime = runtime.from_handlers(handlers.new(tx))

    case
      transaction_program_interpreter.run_with_state(
        program,
        transaction_runtime,
        ctx,
        program_state.new_state(),
      )
    {
      #(Ok(value), state) -> Ok(#(value, reverse_effect_measurements(state)))
      #(Error(err), state) -> Error(#(err, reverse_effect_measurements(state)))
    }
  })
  |> collapse_transaction_result
}

fn collapse_transaction_result(
  result: Result(
    #(a, program_state.State),
    transaction_handlers.RunError(#(error.Error, program_state.State)),
  ),
) -> #(Result(a, error.DbTransactionError), program_state.State) {
  case result {
    Ok(#(value, state)) -> #(Ok(value), state)
    Error(transaction_handlers.MissingConnection) -> #(
      Error(error.DbTransactionError("Missing transaction db")),
      program_state.new_state(),
    )
    Error(transaction_handlers.TransactionError(pog.TransactionRolledBack(#(
      err,
      state,
    )))) -> #(Error(error.DbTransactionError(string.inspect(err))), state)
    Error(transaction_handlers.TransactionError(err)) -> #(
      Error(error.DbTransactionError(string.inspect(err))),
      program_state.new_state(),
    )
  }
}

fn reverse_effect_measurements(
  state: program_state.State,
) -> program_state.State {
  program_state.State(
    ..state,
    effect_measurements: list.reverse(state.effect_measurements),
  )
}
