import glot_backend/context
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/effect_trace
import glot_backend/effect/error
import glot_backend/effect/job/job_algebra
import glot_backend/effect/program_state
import glot_backend/effect/program_types
import glot_backend/effect/runtime
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/user_action/user_action_algebra
import glot_backend/erlang

pub fn run_with_state(
  effect: program_types.TransactionProgram(a),
  runtime: runtime.Runtime,
  ctx: context.Context,
  state: program_state.State,
) -> #(Result(a, error.Error), program_state.State) {
  let continue = fn(next_effect, next_state) {
    run_with_state(next_effect, runtime, ctx, next_state)
  }

  case effect {
    program_types.TxPure(value) -> #(Ok(value), state)
    program_types.TxFail(error) -> #(Error(error), state)
    program_types.TxImpure(effect) ->
      case effect {
        program_types.AuthEffect(effect) ->
          run_auth_effect(effect, ctx, runtime, state, continue)
        program_types.JobEffect(effect) ->
          run_job_effect(effect, runtime, state, continue)
        program_types.SnippetEffect(effect) ->
          run_snippet_effect(effect, runtime, state, continue)
        program_types.UserActionEffect(effect) ->
          run_user_action_effect(effect, runtime, state, continue)
      }
  }
}

fn run_auth_effect(
  effect: auth_algebra.AuthEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.TransactionProgram(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    auth_algebra.GetUserByEmail(email:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.auth.get_user_by_email(ctx.regexes.is_email, email)
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
    auth_algebra.ListLoginTokensByUser(user_id:, limit:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result =
        runtime.handlers.auth.list_login_tokens_by_user(user_id, limit)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.AuthEffectName(
                auth_algebra.ListLoginTokensByUserEffectName,
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
              auth_algebra.ListLoginTokensByUserEffectName,
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
        runtime.handlers.auth.get_session_by_token(ctx.regexes.is_email, token)
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
      let result = runtime.handlers.auth.create_user(user)
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
    auth_algebra.UpdateUser(user: user, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.auth.update_user(user)
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
    auth_algebra.CreateSession(session: session, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.auth.create_session(session)
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
    auth_algebra.CreateLoginToken(login_token: login_token, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.auth.create_login_token(login_token)
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
      let result = runtime.handlers.auth.update_login_token(login_token)
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
  }
}

fn run_job_effect(
  effect: job_algebra.JobEffect(program_types.TransactionProgram(a)),
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.TransactionProgram(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    job_algebra.GetNextJob(now:, pending_status:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.job.get_next_job(now, pending_status)
      case result {
        Ok(value) ->
          continue(
            next(value),
            program_state.add_effect_measurement(
              state,
              effect_trace.JobEffectName(job_algebra.GetNextJobEffectName),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.JobEffectName(job_algebra.GetNextJobEffectName),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    job_algebra.CreateJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.job.create_job(job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.JobEffectName(job_algebra.CreateJobEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    job_algebra.UpdateJob(job, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.job.update_job(job)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.JobEffectName(job_algebra.UpdateJobEffectName),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}

fn run_snippet_effect(
  effect: snippet_algebra.SnippetEffect(program_types.TransactionProgram(a)),
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.TransactionProgram(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    snippet_algebra.GetSnippetById(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.snippet.get_snippet_by_id(id)
      case result {
        Ok(_) ->
          continue(
            next(result),
            program_state.add_effect_measurement(
              state,
              effect_trace.SnippetEffectName(
                snippet_algebra.GetSnippetByIdEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.SnippetEffectName(
              snippet_algebra.GetSnippetByIdEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    snippet_algebra.GetSnippetBySlug(slug:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.snippet.get_snippet_by_slug(slug)
      case result {
        Ok(_) ->
          continue(
            next(result),
            program_state.add_effect_measurement(
              state,
              effect_trace.SnippetEffectName(
                snippet_algebra.GetSnippetBySlugEffectName,
              ),
              effect_trace.DbReadEffectCategory,
              started_at,
            ),
          )
        Error(error) -> #(
          Error(error.QueryError(error)),
          program_state.add_effect_measurement(
            state,
            effect_trace.SnippetEffectName(
              snippet_algebra.GetSnippetBySlugEffectName,
            ),
            effect_trace.DbReadEffectCategory,
            started_at,
          ),
        )
      }
    }
    snippet_algebra.DeleteSnippet(id:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.snippet.delete_snippet(id)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(
            snippet_algebra.DeleteSnippetEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    snippet_algebra.CreateSnippet(snippet:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.snippet.create_snippet(snippet)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(
            snippet_algebra.CreateSnippetEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
    snippet_algebra.UpdateSnippet(snippet:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.snippet.update_snippet(snippet)
      continue(
        next(result),
        program_state.add_effect_measurement(
          state,
          effect_trace.SnippetEffectName(
            snippet_algebra.UpdateSnippetEffectName,
          ),
          effect_trace.DbWriteEffectCategory,
          started_at,
        ),
      )
    }
  }
}

fn run_user_action_effect(
  effect: user_action_algebra.UserActionEffect(
    program_types.TransactionProgram(a),
  ),
  runtime: runtime.Runtime,
  state: program_state.State,
  continue: fn(program_types.TransactionProgram(a), program_state.State) ->
    #(Result(a, error.Error), program_state.State),
) -> #(Result(a, error.Error), program_state.State) {
  case effect {
    user_action_algebra.CountUserActions(filter:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.user_action.count_user_actions(filter)
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
    user_action_algebra.CreateUserAction(user_action: user_action, next: next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = runtime.handlers.user_action.create_user_action(user_action)
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
