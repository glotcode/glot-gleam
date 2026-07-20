import gleam/int
import gleam/option
import gleam/result
import gleam/string
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/adapter/database_ports
import glot_backend/system/effect/transaction/transaction_port
import pog

type CallbackError {
  CallbackRolledBack
  CallbackStatementTimeoutSetupError(pog.QueryError)
}

pub fn new(db: db_helpers.Db) -> transaction_port.TransactionPort {
  transaction_port.new(fn(timeout_ms, callback) {
    pog.transaction(db_helpers.connection(db), fn(tx) {
      case configure_statement_timeout(tx, timeout_ms) {
        Ok(_) ->
          db_helpers.new(tx)
          |> db_helpers.override_timeout(option.Some(timeout_ms))
          |> database_ports.new
          |> callback
          |> result.map_error(fn(_) { CallbackRolledBack })
        Error(err) -> Error(CallbackStatementTimeoutSetupError(err))
      }
    })
    |> result.map_error(map_run_error)
  })
}

fn map_run_error(
  err: pog.TransactionError(CallbackError),
) -> transaction_port.AdapterRunError {
  case err {
    pog.TransactionQueryError(query_error) ->
      transaction_port.AdapterTransactionQueryError(string.inspect(query_error))
    pog.TransactionRolledBack(CallbackRolledBack) ->
      transaction_port.AdapterCallbackRolledBack
    pog.TransactionRolledBack(CallbackStatementTimeoutSetupError(query_error)) ->
      transaction_port.AdapterStatementTimeoutSetupError(string.inspect(
        query_error,
      ))
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
