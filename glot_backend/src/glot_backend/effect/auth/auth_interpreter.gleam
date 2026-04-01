import glot_backend/effect/auth/auth
import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/transaction/transaction_command
import glot_backend/effect/types
import glot_backend/erlang

pub fn run(
  effect: auth.AuthEffect(types.Program(a)),
  handlers: runtime_types.Handlers,
  state: types.State,
  continue: fn(types.Program(a), types.State) -> #(Result(a, error.Error), types.State),
  measure: fn(types.State, types.EffectName, Int) -> types.State,
) -> #(Result(a, error.Error), types.State) {
  case effect {
    auth.GetUserByEmail(email:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.get_user_by_email(email)
      case result {
        Ok(value) ->
          continue(
            next(value),
            measure(
              state,
              types.RunQueryEffect(types.AuthQueryName(auth.GetUserByEmailQuery)),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            measure(
              state,
              types.RunQueryEffect(types.AuthQueryName(auth.GetUserByEmailQuery)),
              started_at,
            ),
          )
      }
    }
    auth.ListLoginTokensByUser(user_id:, limit:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.list_login_tokens_by_user(user_id, limit)
      case result {
        Ok(value) ->
          continue(
            next(value),
            measure(
              state,
              types.RunQueryEffect(
                types.AuthQueryName(auth.ListLoginTokensByUserQuery),
              ),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            measure(
              state,
              types.RunQueryEffect(
                types.AuthQueryName(auth.ListLoginTokensByUserQuery),
              ),
              started_at,
            ),
          )
      }
    }
    auth.GetSessionByToken(token:, next:) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.get_session_by_token(token)
      case result {
        Ok(value) ->
          continue(
            next(value),
            measure(
              state,
              types.RunQueryEffect(types.AuthQueryName(auth.GetSessionByTokenQuery)),
              started_at,
            ),
          )
        Error(error) ->
          #(
            Error(error.QueryError(error)),
            measure(
              state,
              types.RunQueryEffect(types.AuthQueryName(auth.GetSessionByTokenQuery)),
              started_at,
            ),
          )
      }
    }
    auth.RunCommand(command, next) -> {
      let started_at = erlang.perf_counter_ns()
      let result = handlers.run_command(transaction_command.AuthCommand(command))
      continue(
        next(result),
        measure(
          state,
          types.RunCommandEffect(
            types.AuthCommandName(auth.command_name(command)),
          ),
          started_at,
        ),
      )
    }
  }
}
