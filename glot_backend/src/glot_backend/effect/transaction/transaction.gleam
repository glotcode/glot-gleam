import glot_backend/effect/effect_model
import glot_backend/effect/error

pub fn run_in_transaction(
  sub_effects: List(effect_model.Program(Nil)),
) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.TransactionEffect(sub_effects, fn(transaction_result) {
      case transaction_result {
        Ok(_) -> effect_model.Pure(Nil)
        Error(err) -> effect_model.Fail(error.TransactionError(err))
      }
    }),
  )
}
