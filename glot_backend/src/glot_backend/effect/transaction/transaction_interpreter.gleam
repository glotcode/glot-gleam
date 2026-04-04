import gleam/list
import gleam/option
import gleam/string
import glot_backend/context
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_backend/effect/program_state
import glot_backend/effect/runtime
import glot_backend/effect/transaction/transaction
import glot_backend/erlang
import pog

pub fn run(
  effect: transaction.TransactionEffect(program_types.Program(a)),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
  run_program: fn(
    program_types.Program(a),
    runtime.Runtime,
    context.Context,
    program_state.State,
  ) -> #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    transaction.Run(program:) -> {
      let started_at = erlang.perf_counter_ns()
      let #(transaction_result, transaction_state) =
        run_in_transaction(runtime, ctx, program, run_program)

      let next_state =
        program_state.add_effect_measurement(
          state,
          effect_trace.TransactionEffectName(
            transaction.RunEffectName,
            transaction_state.effect_measurements,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        )

      case transaction_result {
        Ok(value) -> continue(program_types.Pure(value), next_state)
        Error(err) -> #(Error(error.TransactionError(err)), next_state)
      }
    }
  }
}

fn run_in_transaction(
  runtime: runtime.Runtime,
  ctx: context.Context,
  program: program_types.Program(a),
  run_program: fn(
    program_types.Program(a),
    runtime.Runtime,
    context.Context,
    program_state.State,
  ) -> #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.DbTransactionError), program_state.State) {
  case runtime.connection {
    option.Some(connection) ->
      pog.transaction(connection, fn(tx) {
        let transaction_runtime = runtime.with_connection(runtime, tx)
        case
          run_program(
            program,
            transaction_runtime,
            ctx,
            program_state.new_state(),
          )
        {
          #(Ok(value), state) -> Ok(#(value, reverse_effect_measurements(state)))
          #(Error(err), state) ->
            Error(#(err, reverse_effect_measurements(state)))
        }
      })
      |> collapse_transaction_result
    option.None ->
      #(
        Error(error.DbTransactionError("Missing transaction db")),
        program_state.new_state(),
      )
  }
}

fn collapse_transaction_result(
  result: Result(
    #(a, program_state.State),
    pog.TransactionError(#(error.Error, program_state.State)),
  ),
) -> #(Result(a, error.DbTransactionError), program_state.State) {
  case result {
    Ok(#(value, state)) -> #(Ok(value), state)
    Error(pog.TransactionRolledBack(#(err, state))) -> #(
      Error(error.DbTransactionError(string.inspect(err))),
      state,
    )
    Error(err) -> #(
      Error(error.DbTransactionError(string.inspect(err))),
      program_state.new_state(),
    )
  }
}

fn reverse_effect_measurements(state: program_state.State) -> program_state.State {
  program_state.State(
    ..state,
    effect_measurements: list.reverse(state.effect_measurements),
  )
}
