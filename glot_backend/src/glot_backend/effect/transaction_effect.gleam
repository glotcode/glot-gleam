import glot_backend/effect/program_types
import glot_backend/effect/error

pub fn run(
  sub_effects: List(program_types.Program(Nil)),
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.TransactionEffect(sub_effects, fn(transaction_result) {
      case transaction_result {
        Ok(_) -> program_types.Pure(Nil)
        Error(err) -> program_types.Fail(error.TransactionError(err))
      }
    }),
  )
}
