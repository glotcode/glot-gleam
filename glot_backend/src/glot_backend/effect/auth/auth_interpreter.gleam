import glot_backend/context
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/handlers
import glot_backend/effect/program_state
import glot_backend/erlang

pub fn run(
  effect: auth_algebra.AuthEffect(next_program),
  ctx: context.Context,
  handlers: handlers.Handlers,
  state: program_state.State,
  continue: fn(next_program, program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    auth_algebra.GetUserByEmail(email:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_user_by_email(ctx.regexes.is_email, email)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(auth_algebra.GetUserByEmailEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth_algebra.GetUserByEmailEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth_algebra.GetUserById(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_user_by_id(ctx.regexes.is_email, id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(auth_algebra.GetUserByIdEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth_algebra.GetUserByIdEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth_algebra.ListUsers(pagination:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.list_users(ctx.regexes.is_email, pagination)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(auth_algebra.ListUsersEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth_algebra.ListUsersEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth_algebra.ListLoginTokensByEmail(email:, limit:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.list_login_tokens_by_email(email, limit)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.ListLoginTokensByEmailEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.ListLoginTokensByEmailEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth_algebra.GetSessionByToken(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.get_session_by_token(ctx.regexes.is_email, token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.GetSessionByTokenEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.GetSessionByTokenEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    auth_algebra.CreateUser(user: user, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_user(user)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.CreateUserEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.CreateAccount(account: account, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_account(account)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.CreateAccountEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.UpdateAccount(account: account, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.update_account(account)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.UpdateAccountEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.UpdateUser(user: user, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.update_user(user)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.UpdateUserEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.DeleteSessionsByAccountId(account_id: account_id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.delete_sessions_by_account_id(account_id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.DeleteSessionsByAccountIdEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.DeleteUsersByAccountId(account_id: account_id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.delete_users_by_account_id(account_id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.DeleteUsersByAccountIdEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.DeleteAccount(account_id: account_id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.delete_account(account_id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.DeleteAccountEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.CreateSession(session: session, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_session(session)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.CreateSessionEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.DeleteSession(id: id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.delete_session(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.DeleteSessionEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.CreateLoginToken(login_token: login_token, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_login_token(login_token)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.CreateLoginTokenEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.UpdateLoginToken(login_token: login_token, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.update_login_token(login_token)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.UpdateLoginTokenEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    auth_algebra.DeleteLoginTokensBefore(before: before, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.delete_login_tokens_before(before)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.DeleteLoginTokensBeforeEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}
