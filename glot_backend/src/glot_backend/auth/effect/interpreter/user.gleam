import glot_backend/auth/effect/algebra as auth_algebra
import glot_backend/auth/effect/algebra/user as user_algebra
import glot_backend/auth/ports/user_store.{type UserStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/request/context
import glot_backend/system/runtime/erlang

pub fn run(
  effect: user_algebra.Effect(next_program),
  ctx: context.Context,
  store: UserStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    user_algebra.GetUserByEmail(email:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_by_email(ctx.regexes.is_email, email)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(user_algebra.GetUserByEmailEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(user_algebra.GetUserByEmailEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    user_algebra.GetUserById(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_by_id(ctx.regexes.is_email, id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(user_algebra.GetUserByIdEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(user_algebra.GetUserByIdEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    user_algebra.ListUsers(pagination:, filters:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.list(ctx.regexes.is_email, pagination, filters)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(user_algebra.ListUsersEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(user_algebra.ListUsersEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    user_algebra.CreateUser(user: user, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create(user)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(user_algebra.CreateUserEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    user_algebra.UpdateUser(user: user, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.update(user)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(user_algebra.UpdateUserEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    user_algebra.DeleteUsersByAccountId(account_id: account_id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_by_account_id(account_id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(user_algebra.DeleteUsersByAccountIdEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(name: user_algebra.EffectName) -> effect_trace.EffectName {
  effect_trace.AuthEffectName(auth_algebra.UserName(name))
}
