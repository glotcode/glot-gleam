import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/user_action/user_action_algebra
import glot_backend/erlang

pub fn run(
  effect: user_action_algebra.UserActionEffect(program_types.Program(a)),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    user_action_algebra.CountUserActions(filter:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.user_action.count_user_actions(filter)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.UserActionEffectName(
                user_action_algebra.CountUserActionsEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.UserActionEffectName(
              user_action_algebra.CountUserActionsEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    user_action_algebra.CreateUserAction(
      user_action: user_action,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.user_action.create_user_action(user_action)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.UserActionEffectName(
            user_action_algebra.CreateUserActionEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
