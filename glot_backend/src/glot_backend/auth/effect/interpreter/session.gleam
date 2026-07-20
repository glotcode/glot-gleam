import glot_backend/auth/effect/algebra as auth_algebra
import glot_backend/auth/effect/algebra/session as session_algebra
import glot_backend/auth/ports/session_store.{type SessionStore}
import glot_backend/system/effect/effect_trace
import glot_backend/system/effect/error
import glot_backend/system/effect/program_state
import glot_backend/system/request/context
import glot_backend/system/runtime/erlang

pub fn run(
  effect: session_algebra.Effect(next_program),
  ctx: context.Context,
  store: SessionStore,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    session_algebra.ListSessionsByUserId(
      user_id:,
      created_since:,
      last_activity_since:,
      next:,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        store.list_by_user_id(user_id, created_since, last_activity_since)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(session_algebra.ListSessionsByUserIdEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(session_algebra.ListSessionsByUserIdEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    session_algebra.GetSessionByToken(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_by_token(ctx.regexes.is_email, token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(session_algebra.GetSessionByTokenEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(session_algebra.GetSessionByTokenEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    session_algebra.GetSessionByTokenForUpdate(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_by_token_for_update(token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(session_algebra.GetSessionByTokenForUpdateEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(session_algebra.GetSessionByTokenForUpdateEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    session_algebra.GetSessionByPreviousToken(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_by_previous_token(ctx.regexes.is_email, token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(session_algebra.GetSessionByPreviousTokenEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(session_algebra.GetSessionByPreviousTokenEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    session_algebra.GetSessionByPreviousTokenForUpdate(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.get_by_previous_token_for_update(token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              trace_name(
                session_algebra.GetSessionByPreviousTokenForUpdateEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            trace_name(
              session_algebra.GetSessionByPreviousTokenForUpdateEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    session_algebra.DeleteSessionsByAccountId(
      account_id: account_id,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_by_account_id(account_id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(session_algebra.DeleteSessionsByAccountIdEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    session_algebra.DeleteExpiredSessions(
      created_before: created_before,
      last_activity_before: last_activity_before,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete_expired(created_before, last_activity_before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(session_algebra.DeleteExpiredSessionsEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    session_algebra.CreateSession(session: session, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.create(session)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(session_algebra.CreateSessionEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    session_algebra.UpdateSession(session: session, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.update(session)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(session_algebra.UpdateSessionEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    session_algebra.DeleteSession(id: id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = store.delete(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          trace_name(session_algebra.DeleteSessionEffectName),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}

fn trace_name(name: session_algebra.EffectName) -> effect_trace.EffectName {
  effect_trace.AuthEffectName(auth_algebra.SessionName(name))
}
