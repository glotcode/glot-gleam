import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/program_types

pub fn to_program(
  result: Result(Nil, db_error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.database_command_error(err))
  }
}

pub fn to_transaction_program(
  result: Result(Nil, db_error.DbCommandError),
) -> program_types.TransactionProgram(Nil) {
  case result {
    Ok(_) -> program_types.TxPure(Nil)
    Error(err) -> program_types.TxFail(error.database_command_error(err))
  }
}
