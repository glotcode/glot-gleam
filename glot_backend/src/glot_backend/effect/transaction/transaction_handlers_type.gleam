import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/program_state

pub type TransactionHandlers {
  TransactionHandlers(
    run_in_transaction: fn(List(effect_model.Program(Nil))) ->
      #(Result(Nil, error.DbTransactionError), program_state.State),
  )
}
