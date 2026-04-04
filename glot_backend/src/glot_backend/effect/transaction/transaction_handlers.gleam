import gleam/option
import gleam/result
import pog

pub opaque type TransactionHandlers {
  TransactionHandlers(connection: option.Option(pog.Connection))
}

pub type RunError(e) {
  MissingConnection
  TransactionError(pog.TransactionError(e))
}

pub fn new(connection: pog.Connection) -> TransactionHandlers {
  TransactionHandlers(connection: option.Some(connection))
}

pub fn none() -> TransactionHandlers {
  TransactionHandlers(connection: option.None)
}

pub fn run(
  handlers: TransactionHandlers,
  f: fn(pog.Connection) -> Result(a, b),
) -> Result(a, RunError(b)) {
  case handlers.connection {
    option.Some(connection) ->
      pog.transaction(connection, f)
      |> result.map_error(TransactionError)
    option.None -> Error(MissingConnection)
  }
}
