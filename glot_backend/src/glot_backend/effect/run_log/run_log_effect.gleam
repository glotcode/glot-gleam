import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_backend/effect/run_log/run_log_algebra
import glot_core/run_log_model.{type RunLog}

pub fn create(run_log: RunLog) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_effect(run_log, next)),
  )
}

pub fn create_tx(run_log: RunLog) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_effect(run_log, tx_next))
}

fn next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}

fn tx_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.TransactionProgram(Nil) {
  case result {
    Ok(_) -> program_types.TxPure(Nil)
    Error(err) -> program_types.TxFail(error.CommandError(err))
  }
}

fn create_effect(
  run_log: RunLog,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.RunLogEffect(run_log_algebra.CreateRunLog(
    run_log: run_log,
    next: next,
  ))
}
