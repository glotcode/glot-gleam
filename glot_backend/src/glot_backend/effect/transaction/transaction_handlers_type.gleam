import glot_backend/effect/effect_model
import glot_backend/effect/error

pub type TransactionHandlers {
  TransactionHandlers(
    run_in_transaction: fn(List(effect_model.Program(Nil))) ->
      #(Result(Nil, error.DbTransactionError), effect_model.State),
  )
}
