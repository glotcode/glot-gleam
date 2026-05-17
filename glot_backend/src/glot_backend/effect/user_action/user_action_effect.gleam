import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/effect/error/db_error
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_algebra
import glot_core/rate_limit
import glot_core/user_action.{type UserAction, type UserActionFilter}

pub fn count_user_actions(
  filter filter: UserActionFilter,
) -> program_types.Program(List(rate_limit.WindowCount)) {
  program_types.Impure(
    program_types.DbEffect(count_user_actions_effect(filter, program_types.Pure)),
  )
}

pub fn create_user_action(
  user_action user_action: UserAction,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_user_action_effect(user_action, command_next)),
  )
}

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

pub fn count_user_actions_tx(
  filter filter: UserActionFilter,
) -> program_types.TransactionProgram(List(rate_limit.WindowCount)) {
  program_types.TxImpure(count_user_actions_effect(filter, program_types.TxPure))
}

pub fn create_user_action_tx(
  user_action user_action: UserAction,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_user_action_effect(user_action, tx_command_next))
}

pub fn delete_before_tx(
  before: Timestamp,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_before_effect(before, tx_command_next))
}

fn tx_command_next(
  result: Result(Nil, db_error.DbCommandError),
) -> program_types.TransactionProgram(Nil) {
  case result {
    Ok(_) -> program_types.TxPure(Nil)
    Error(err) -> program_types.TxFail(error.database_command_error(err))
  }
}

fn count_user_actions_effect(
  filter: UserActionFilter,
  next: fn(List(rate_limit.WindowCount)) -> next,
) -> program_types.DbEffect(next) {
  program_types.UserActionEffect(user_action_algebra.CountUserActions(
    filter: filter,
    next: next,
  ))
}

fn create_user_action_effect(
  user_action: UserAction,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.UserActionEffect(user_action_algebra.CreateUserAction(
    user_action: user_action,
    next: next,
  ))
}

fn delete_before_effect(
  before: Timestamp,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.UserActionEffect(user_action_algebra.DeleteBefore(
    before: before,
    next: next,
  ))
}
