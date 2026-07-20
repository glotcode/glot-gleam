import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/program_state
import glot_backend/system/effect/program_types
import glot_backend/system/effect/runtime
import glot_backend/system/effect/service_ports
import glot_backend/system/effect/transaction/transaction_algebra
import glot_backend/system/effect/transaction/transaction_port
import glot_backend/system/effect/transaction/transaction_program_interpreter
import glot_backend/system/request/context
import glot_backend/system/runtime/erlang

const default_statement_timeout_ms = 10_000

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
            rolled_back: result.is_error(transaction_result),
          ),
          effect_trace.DatabaseWriteEffect,
          started_at,
        )

      case transaction_result {
        Ok(value) -> continue(value, next_state)
        Error(err) -> #(
          Error(error.database_transaction_error(err)),
          next_state,
        )
      }
    }
  }
}

fn run_in_transaction(
  runtime: runtime.Runtime,
  ctx: context.Context,
  program: program_types.TransactionProgram(program_types.Program(a)),
) -> #(
  Result(program_types.Program(a), db_error.DbTransactionError),
  program_state.State,
) {
  let timeout_ms =
    context.remaining_timeout_ms(ctx)
    |> option.unwrap(default_statement_timeout_ms)

  transaction_port.run(
    runtime.services.transaction,
    timeout_ms,
    fn(tx_database) {
      let transaction_runtime =
        runtime.new(
          service_ports.ServicePorts(..runtime.services, database: tx_database),
        )

      case
        transaction_program_interpreter.run_with_state(
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
    },
  )
  |> collapse_transaction_result
}

fn collapse_transaction_result(
  result: Result(
    #(a, program_state.State),
    transaction_port.RunError(#(error.Error, program_state.State)),
  ),
) -> #(Result(a, db_error.DbTransactionError), program_state.State) {
  case result {
    Ok(#(value, state)) -> #(Ok(value), state)
    Error(transaction_port.MissingConnection) -> #(
      Error(db_error.DbTransactionError("Missing transaction db")),
      program_state.new_state(),
    )
    Error(transaction_port.StatementTimeoutSetupError(query_error)) -> #(
      Error(db_error.DbTransactionError(query_error)),
      program_state.new_state(),
    )
    Error(transaction_port.TransactionQueryError(query_error)) -> #(
      Error(db_error.DbTransactionError(query_error)),
      program_state.new_state(),
    )
    Error(transaction_port.AdapterContractViolation(contract_error)) -> #(
      Error(db_error.DbTransactionError(
        "Transaction adapter contract violation: "
        <> transaction_port.adapter_contract_error_to_string(contract_error),
      )),
      program_state.new_state(),
    )
    Error(transaction_port.CallbackRolledBack(#(err, state))) -> #(
      Error(db_error.DbTransactionError(string.inspect(err))),
      state,
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
