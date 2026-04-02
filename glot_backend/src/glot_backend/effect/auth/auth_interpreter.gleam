import glot_backend/context
import glot_backend/effect/auth/auth
import glot_backend/effect/program_types
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: auth.AuthEffect(program_types.Program(a)),
  ctx: context.Context,
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(program_types.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    auth.GetUserByEmail(email:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_user_by_email(ctx.regexes.is_email, email)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(auth.GetUserByEmailEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth.GetUserByEmailEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth.ListLoginTokensByUser(user_id:, limit:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.list_login_tokens_by_user(user_id, limit)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(auth.ListLoginTokensByUserEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth.ListLoginTokensByUserEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth.GetSessionByToken(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_session_by_token(ctx.regexes.is_email, token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(auth.GetSessionByTokenEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth.GetSessionByTokenEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth.CreateUser(user: user, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_user(user)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth.CreateUserEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth.CreateSession(session: session, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_session(session)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth.CreateSessionEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth.CreateLoginToken(login_token: login_token, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_login_token(login_token)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth.CreateLoginTokenEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth.UpdateLoginToken(login_token: login_token, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.update_login_token(login_token)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth.UpdateLoginTokenEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
