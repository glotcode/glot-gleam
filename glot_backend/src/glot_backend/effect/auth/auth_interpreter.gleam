import glot_backend/effect/auth/auth
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: auth.AuthEffect(effect_model.Program(a)),
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(effect_model.Program(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    auth.GetUserByEmail(email:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_user_by_email(email)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_model.AuthEffectName(auth.GetUserByEmailEffectName),
              effect_model.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_model.AuthEffectName(auth.GetUserByEmailEffectName),
            effect_model.DbReadEffectCategory,
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
              effect_model.AuthEffectName(auth.ListLoginTokensByUserEffectName),
              effect_model.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_model.AuthEffectName(auth.ListLoginTokensByUserEffectName),
            effect_model.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth.GetSessionByToken(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_session_by_token(token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_model.AuthEffectName(auth.GetSessionByTokenEffectName),
              effect_model.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_model.AuthEffectName(auth.GetSessionByTokenEffectName),
            effect_model.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth.InsertUser(id:, email:, created_at:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.insert_user(id, email, created_at)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_model.AuthEffectName(auth.InsertUserEffectName),
          effect_model.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth.InsertSession(
      id: id,
      user_id: user_id,
      token: token,
      ip: ip,
      user_agent: user_agent,
      created_at: created_at,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.insert_session(
          id,
          user_id,
          token,
          ip,
          user_agent,
          created_at,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_model.AuthEffectName(auth.InsertSessionEffectName),
          effect_model.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth.InsertLoginToken(
      id: id,
      user_id: user_id,
      token: token,
      created_at: created_at,
      used_at: used_at,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.insert_login_token(
          id,
          user_id,
          token,
          created_at,
          used_at,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_model.AuthEffectName(auth.InsertLoginTokenEffectName),
          effect_model.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth.UpdateLoginToken(
      user_id: user_id,
      token: token,
      created_at: created_at,
      used_at: used_at,
      id: id,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.update_login_token(
          user_id,
          token,
          created_at,
          used_at,
          id,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_model.AuthEffectName(auth.UpdateLoginTokenEffectName),
          effect_model.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
