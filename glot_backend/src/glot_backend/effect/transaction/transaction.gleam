import glot_backend/effect/effect_model
import glot_backend/effect/error

pub fn run_in_transaction(
  commands: List(effect_model.Program(Nil)),
) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.TransactionEffect(commands, fn(transaction_result) {
      case transaction_result {
        Ok(_) -> effect_model.Pure(Nil)
        Error(err) -> effect_model.Fail(error.TransactionError(err))
      }
    }),
  )
}

pub fn attempt_run_in_transaction(
  commands: List(effect_model.Program(Nil)),
) -> effect_model.Program(Result(Nil, error.DbTransactionError)) {
  effect_model.Impure(effect_model.TransactionEffect(commands, effect_model.Pure))
}
