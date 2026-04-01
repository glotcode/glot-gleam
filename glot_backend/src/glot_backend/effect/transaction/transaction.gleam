import glot_backend/effect/error
import glot_backend/effect/types

pub fn run_in_transaction(
  commands: List(types.Program(Nil)),
) -> types.Program(Nil) {
  types.Impure(
    types.TransactionEffect(commands, fn(transaction_result) {
      case transaction_result {
        Ok(_) -> types.Pure(Nil)
        Error(err) -> types.Fail(error.TransactionError(err))
      }
    }),
  )
}

pub fn attempt_run_in_transaction(
  commands: List(types.Program(Nil)),
) -> types.Program(Result(Nil, error.DbTransactionError)) {
  types.Impure(types.TransactionEffect(commands, types.Pure))
}
