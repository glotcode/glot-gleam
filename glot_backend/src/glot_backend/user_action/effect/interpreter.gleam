import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/runtime/erlang
import glot_backend/user_action/effect/algebra as user_action_algebra
import glot_backend/user_action/ports/store.{type Store}

pub fn run(
  effect: user_action_algebra.UserActionEffect(next_program),
  store: Store,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    user_action_algebra.CountUserActions(filter:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.count(filter)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.UserActionEffectName(
                user_action_algebra.CountUserActionsEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.UserActionEffectName(
              user_action_algebra.CountUserActionsEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    user_action_algebra.CreateUserAction(user_action: user_action, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create(user_action)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.UserActionEffectName(
            user_action_algebra.CreateUserActionEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    user_action_algebra.DeleteBefore(before:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_before(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.UserActionEffectName(
            user_action_algebra.DeleteBeforeEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}
