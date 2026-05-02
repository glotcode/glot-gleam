import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/program_types

pub fn delete_before(
  before: Timestamp,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_before_effect(before, command_next)),
  )
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}

fn delete_before_effect(
  before: Timestamp,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.PageLogEffect(page_log_algebra.DeletePageLogBefore(
    before: before,
    next: next,
  ))
}
