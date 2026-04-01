import gleam/list
import gleam/result
import gleam/string
import glot_backend/effect/auth/auth
import glot_backend/effect/core/core
import glot_backend/effect/error
import glot_backend/effect/runtime_types
import glot_backend/effect/snippet/snippet
import glot_backend/effect/transaction/transaction_command
import glot_backend/effect/types
import glot_backend/erlang

pub fn run(
  commands: List(types.Program(Nil)),
  next: fn(Result(Nil, error.DbTransactionError)) -> types.Program(a),
  handlers: runtime_types.Handlers,
  state: types.State,
  continue: fn(types.Program(a), types.State) -> #(Result(a, error.Error), types.State),
  measure: fn(types.State, types.EffectName, Int) -> types.State,
) -> #(Result(a, error.Error), types.State) {
  let started_at = erlang.perf_counter_ns()
  case collect_transaction_commands(commands) {
    Ok(lowered_commands) -> {
      let transaction_result = handlers.run_in_transaction(lowered_commands)
      continue(
        next(transaction_result),
        measure(
          state,
          types.RunInTransactionEffect(
            list.map(lowered_commands, transaction_command_name),
          ),
          started_at,
        ),
      )
    }
    Error(error) ->
      #(
        Error(error.TransactionError(error)),
        measure(state, types.RunInTransactionEffect([]), started_at),
      )
  }
}

fn collect_transaction_commands(
  commands: List(types.Program(Nil)),
) -> Result(List(transaction_command.TransactionCommand), error.DbTransactionError) {
  case commands {
    [] -> Ok([])
    [first, ..rest] -> {
      use first_commands <- result.try(program_to_transaction_commands(first))
      use rest_commands <- result.try(collect_transaction_commands(rest))
      Ok(list.append(first_commands, rest_commands))
    }
  }
}

fn program_to_transaction_commands(
  program: types.Program(Nil),
) -> Result(List(transaction_command.TransactionCommand), error.DbTransactionError) {
  case program {
    types.Pure(Nil) -> Ok([])
    types.Fail(error) ->
      Error(error.DbTransactionError(
        "Invalid transaction program failed: " <> string.inspect(error),
      ))
    types.Impure(effect) ->
      case effect {
        types.CoreEffect(core.RunCommand(command, next)) -> {
          use commands <- result.try(program_to_transaction_commands(next(Ok(Nil))))
          Ok([transaction_command.CoreCommand(command), ..commands])
        }
        types.AuthEffect(auth.RunCommand(command, next)) -> {
          use commands <- result.try(program_to_transaction_commands(next(Ok(Nil))))
          Ok([transaction_command.AuthCommand(command), ..commands])
        }
        types.SnippetEffect(snippet.RunCommand(command, next)) -> {
          use commands <- result.try(program_to_transaction_commands(next(Ok(Nil))))
          Ok([transaction_command.SnippetCommand(command), ..commands])
        }
        _ ->
          Error(error.DbTransactionError(
            "Unsupported effect inside transaction program",
          ))
      }
  }
}

fn transaction_command_name(
  command: transaction_command.TransactionCommand,
) -> types.DbCommandName {
  case command {
    transaction_command.CoreCommand(command) ->
      types.CoreCommandName(core.command_name(command))
    transaction_command.AuthCommand(command) ->
      types.AuthCommandName(auth.command_name(command))
    transaction_command.SnippetCommand(command) ->
      types.SnippetCommandName(snippet.command_name(command))
  }
}
