import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action as user_action_effect_family
import glot_core/rate_limit
import glot_core/user_action

pub fn count_user_actions(
  filter filter: user_action.UserActionFilter,
) -> program_types.Program(List(rate_limit.WindowCount)) {
  program_types.Impure(
    program_types.UserActionEffect(user_action_effect_family.CountUserActions(
      filter: filter,
      next: program_types.Pure,
    )),
  )
}

pub fn create_user_action(
  user_action user_action: user_action.UserAction,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.UserActionEffect(user_action_effect_family.CreateUserAction(
      user_action: user_action,
      next: command_next,
    )),
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
