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
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth_algebra.GetUserByEmailEffectName),
            effect_trace.DatabaseReadEffect,
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
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth_algebra.GetUserByIdEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.ListUsers(pagination:, filters:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.list_users(ctx.regexes.is_email, pagination, filters)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(auth_algebra.ListUsersEffectName),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(auth_algebra.ListUsersEffectName),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.ListLoginTokensByEmail(email:, created_since:, limit:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.list_login_tokens_by_email(email, created_since, limit)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.ListLoginTokensByEmailEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.ListLoginTokensByEmailEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.GetPasskeyCredentialByCredentialId(credential_id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.get_passkey_credential_by_credential_id(credential_id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.GetPasskeyCredentialByCredentialIdEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.GetPasskeyCredentialByCredentialIdEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.ListPasskeyCredentialsByUserId(user_id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.list_passkey_credentials_by_user_id(user_id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.ListPasskeyCredentialsByUserIdEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.ListPasskeyCredentialsByUserIdEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.ListSessionsByUserId(
      user_id:,
      created_since:,
      last_activity_since:,
      next:,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.list_sessions_by_user_id(
          user_id,
          created_since,
          last_activity_since,
        )
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.ListSessionsByUserIdEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.ListSessionsByUserIdEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.GetPasskeyChallengeById(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_passkey_challenge_by_id(id)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.GetPasskeyChallengeByIdEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.GetPasskeyChallengeByIdEffectName,
            ),
            effect_trace.DatabaseReadEffect,
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
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.GetSessionByTokenEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.GetSessionByTokenForUpdate(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_session_by_token_for_update(token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.GetSessionByTokenForUpdateEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.GetSessionByTokenForUpdateEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.GetSessionByPreviousToken(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.get_session_by_previous_token(ctx.regexes.is_email, token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.GetSessionByPreviousTokenEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.GetSessionByPreviousTokenEffectName,
            ),
            effect_trace.DatabaseReadEffect,
            started_at,
          ),
        )
      }
    }
    auth_algebra.GetSessionByPreviousTokenForUpdate(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.get_session_by_previous_token_for_update(token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.GetSessionByPreviousTokenForUpdateEffectName,
              ),
              effect_trace.DatabaseReadEffect,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.database_query_error(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.AuthEffectName(
              auth_algebra.GetSessionByPreviousTokenForUpdateEffectName,
            ),
            effect_trace.DatabaseReadEffect,
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
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    auth_algebra.DeleteExpiredSessions(
      created_before: created_before,
      last_activity_before: last_activity_before,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        handlers.auth.delete_expired_sessions(
          created_before,
          last_activity_before,
        )
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.DeleteExpiredSessionsEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    auth_algebra.UpdateSession(session: session, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.update_session(session)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(auth_algebra.UpdateSessionEffectName),
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    auth_algebra.CreatePasskeyCredential(
      passkey_credential: passkey_credential,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_passkey_credential(passkey_credential)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.CreatePasskeyCredentialEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    auth_algebra.CreatePasskeyChallenge(
      passkey_challenge: passkey_challenge,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.create_passkey_challenge(passkey_challenge)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.CreatePasskeyChallengeEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    auth_algebra.DeletePasskeyCredential(id: id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.delete_passkey_credential(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.DeletePasskeyCredentialEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    auth_algebra.UpdatePasskeyCredential(
      passkey_credential: passkey_credential,
      next: next,
    ) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.update_passkey_credential(passkey_credential)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.UpdatePasskeyCredentialEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
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
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
    auth_algebra.DeletePasskeyChallenge(id: id, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.auth.delete_passkey_challenge(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.AuthEffectName(
            auth_algebra.DeletePasskeyChallengeEffectName,
          ),
          effect_trace.DatabaseWriteEffect,
          started_at,
        ),
      )
    }
  }
}
