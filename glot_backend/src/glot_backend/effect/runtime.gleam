import glot_backend/effect/program_types
import glot_backend/effect/error
import glot_backend/effect/program_state

pub type Runtime {
  Runtime(
    run_in_transaction: fn(List(program_types.Program(Nil))) ->
      #(Result(Nil, error.DbTransactionError), program_state.State),
  )
}

pub fn from_runner(
  run_in_transaction: fn(List(program_types.Program(Nil))) ->
    #(Result(Nil, error.DbTransactionError), program_state.State),
) -> Runtime {
  Runtime(run_in_transaction: run_in_transaction)
}
