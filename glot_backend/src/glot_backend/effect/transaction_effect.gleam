import gleam/list
import gleam/option
import gleam/string
import glot_backend/context
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/effect/program
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import pog

pub fn run(p: program_types.Program(a)) -> program_types.Program(a) {
  program_types.Impure(program_types.TransactionEffect(fn(db, ctx) {
    let #(transaction_result, tx_state) = run_in_transaction(db, ctx, p)

    #(
      case transaction_result {
        Ok(value) -> program_types.Pure(value)
        Error(err) -> program_types.Fail(error.TransactionError(err))
      },
      tx_state,
    )
  }))
}

pub fn run_all(
  sub_effects: List(program_types.Program(Nil)),
) -> program_types.Program(Nil) {
  run(sequence(sub_effects))
}

fn sequence(
  programs: List(program_types.Program(Nil)),
) -> program_types.Program(Nil) {
  list.fold(programs, program.succeed(Nil), fn(acc, p) {
    program.and_then(acc, fn(_) { p })
  })
}

fn run_in_transaction(
  db: pog.Connection,
  ctx: context.Context,
  p: program_types.Program(a),
) -> #(Result(a, error.DbTransactionError), program_state.State) {
  pog.transaction(db, fn(tx) {
    let tx_handlers = handlers.new(tx)
    case interpreter.run(p, tx_handlers, option.Some(tx), ctx) {
      #(Ok(value), state) -> Ok(#(value, state))
      #(Error(err), state) -> Error(#(err, state))
    }
  })
  |> collapse_transaction_result
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
