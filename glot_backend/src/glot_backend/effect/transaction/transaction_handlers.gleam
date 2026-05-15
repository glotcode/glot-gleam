import gleam/int
import gleam/option
import gleam/result
import glot_backend/helpers/db_helpers
import pog

pub opaque type TransactionHandlers {
  TransactionHandlers(db: option.Option(db_helpers.Db))
}

pub type RunError(e) {
  MissingConnection
  StatementTimeoutSetupError(pog.QueryError)
  TransactionError(pog.TransactionError(e))
}

type CallbackError(e) {
  CallbackError(e)
  CallbackStatementTimeoutSetupError(pog.QueryError)
}

pub fn new(db: db_helpers.Db) -> TransactionHandlers {
  TransactionHandlers(db: option.Some(db))
}

pub fn none() -> TransactionHandlers {
  TransactionHandlers(db: option.None)
}

pub fn run(
  handlers: TransactionHandlers,
  timeout_ms timeout_ms: Int,
  callback callback: fn(db_helpers.Db) -> Result(a, b),
) -> Result(a, RunError(b)) {
  case handlers.db {
    option.Some(db) ->
      pog.transaction(db_helpers.connection(db), fn(tx) {
        case configure_statement_timeout(tx, timeout_ms) {
          Ok(_) ->
            callback(db_helpers.override_timeout(
              db_helpers.new(tx),
              option.Some(timeout_ms),
            ))
            |> result.map_error(CallbackError)
          Error(err) -> Error(CallbackStatementTimeoutSetupError(err))
        }
      })
      |> result.map_error(map_run_error)
    option.None -> Error(MissingConnection)
  }
}

fn map_run_error(err: pog.TransactionError(CallbackError(a))) -> RunError(a) {
  case err {
    pog.TransactionQueryError(query_error) ->
      TransactionError(pog.TransactionQueryError(query_error))
    pog.TransactionRolledBack(CallbackError(err)) ->
      TransactionError(pog.TransactionRolledBack(err))
    pog.TransactionRolledBack(CallbackStatementTimeoutSetupError(query_error)) ->
      StatementTimeoutSetupError(query_error)
  }
}

fn configure_statement_timeout(
  tx: pog.Connection,
  timeout_ms: Int,
) -> Result(Nil, pog.QueryError) {
  pog.query("set local statement_timeout = " <> int.to_string(timeout_ms))
  |> pog.execute(tx)
  |> result.map(fn(_) { Nil })
}
