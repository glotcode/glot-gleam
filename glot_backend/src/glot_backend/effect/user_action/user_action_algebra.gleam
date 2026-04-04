import glot_backend/effect/error
import glot_core/rate_limit
import glot_core/user_action

pub type UserActionEffect(next) {
  CountUserActions(
    filter: user_action.UserActionFilter,
    next: fn(List(rate_limit.WindowCount)) -> next,
  )
  CreateUserAction(
    user_action: user_action.UserAction,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(
  effect: UserActionEffect(a),
  f: fn(a) -> b,
) -> UserActionEffect(b) {
  case effect {
    CountUserActions(filter:, next:) ->
      CountUserActions(filter: filter, next: fn(value) { f(next(value)) })
    CreateUserAction(user_action: user_action, next: next) ->
      CreateUserAction(
        user_action: user_action,
        next: fn(value) { f(next(value)) },
      )
  }
}

pub type EffectName {
  CountUserActionsEffectName
  CreateUserActionEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    CountUserActionsEffectName -> "count_user_actions"
    CreateUserActionEffectName -> "create_user_action"
  }
}
