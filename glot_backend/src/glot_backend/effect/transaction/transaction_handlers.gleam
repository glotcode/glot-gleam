import gleam/result
import gleam/string
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/core/core_handlers
import glot_backend/effect/error
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/transaction/transaction_command
import glot_backend/effect/types
import pog

pub fn run_command(
  db: pog.Connection,
  command: types.TransactionCommand,
) -> Result(Nil, error.DbCommandError) {
  case command {
    transaction_command.CoreCommand(command) -> core_handlers.run_command(db, command)
    transaction_command.AuthCommand(command) -> auth_handlers.run_command(db, command)
    transaction_command.SnippetCommand(command) ->
      snippet_handlers.run_command(db, command)
  }
}

pub fn run_in_transaction(
  db: pog.Connection,
  commands: List(types.TransactionCommand),
) -> Result(Nil, error.DbTransactionError) {
  pog.transaction(db, fn(tx) { execute_commands(tx, commands) })
  |> result.map(fn(_) { Nil })
  |> result.map_error(fn(err) {
    error.DbTransactionError(string.inspect(err))
  })
}

fn execute_commands(
  db: pog.Connection,
  commands: List(types.TransactionCommand),
) -> Result(Nil, error.DbCommandError) {
  case commands {
    [] -> Ok(Nil)
    [command, ..rest] -> {
      use _ <- result.try(run_command(db, command))
      execute_commands(db, rest)
    }
  }
}
