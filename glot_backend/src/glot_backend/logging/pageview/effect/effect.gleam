import gleam/time/timestamp.{type Timestamp}
import glot_backend/logging/effect/effect as logging_effect
import glot_backend/logging/pageview/effect/algebra as pageview_log_algebra
import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/program_types

pub fn delete_before(before: Timestamp) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_before_effect(before, command_next)),
  )
}

fn command_next(
  result: Result(Nil, db_error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.database_command_error(err))
  }
}

fn delete_before_effect(
  before: Timestamp,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  logging_effect.pageview(pageview_log_algebra.DeletePageviewLogBefore(
    before: before,
    next: next,
  ))
}
