import gleam/erlang/process
import gleam/result
import glot_backend/system/effect/database_ports.{type DatabasePorts}

pub opaque type TransactionPort {
  TransactionPort(
    run_transaction: fn(Int, fn(DatabasePorts) -> Result(Nil, Nil)) ->
      Result(Nil, AdapterRunError),
  )
}

pub type AdapterRunError {
  AdapterMissingConnection
  AdapterStatementTimeoutSetupError(String)
  AdapterTransactionQueryError(String)
  AdapterCallbackRolledBack
}

pub type RunError(e) {
  MissingConnection
  StatementTimeoutSetupError(String)
  TransactionQueryError(String)
  AdapterContractViolation(AdapterContractError)
  CallbackRolledBack(e)
}

pub type AdapterContractError {
  CallbackNotInvoked
  CallbackInvokedMultipleTimes
  FailedCallbackCommitted
  SuccessfulCallbackRolledBack
}

type AdapterOutcome {
  Committed
  RolledBack
}

/// Creates a transaction port from an adapter operation.
///
/// The adapter must invoke the callback exactly once before returning `Ok` or
/// `AdapterCallbackRolledBack`. Infrastructure failures may return before the
/// callback is invoked.
pub fn new(
  run_transaction: fn(Int, fn(DatabasePorts) -> Result(Nil, Nil)) ->
    Result(Nil, AdapterRunError),
) -> TransactionPort {
  TransactionPort(run_transaction:)
}

pub fn none() -> TransactionPort {
  new(fn(_, _) { Error(AdapterMissingConnection) })
}

/// Runs a typed callback through the implementation-neutral transaction port.
///
/// The adapter only needs to know whether the callback committed or rolled
/// back. Its typed result stays at this boundary and is returned after the
/// adapter has completed the transaction.
pub fn run(
  port: TransactionPort,
  timeout_ms timeout_ms: Int,
  callback callback: fn(DatabasePorts) -> Result(a, b),
) -> Result(a, RunError(b)) {
  let callback_result = process.new_subject()
  let callback_token = process.new_subject()
  let duplicate_callback = process.new_subject()
  process.send(callback_token, Nil)

  let adapter_result =
    port.run_transaction(timeout_ms, fn(database_ports) {
      case process.receive(callback_token, 0) {
        Ok(Nil) -> {
          let result = callback(database_ports)
          process.send(callback_result, result)
          result.map(result, fn(_) { Nil })
          |> result.map_error(fn(_) { Nil })
        }
        Error(_) -> {
          process.send(duplicate_callback, Nil)
          Error(Nil)
        }
      }
    })

  // Close the callback after the synchronous adapter operation has returned.
  // This also prevents a late callback from executing business logic.
  let _ = process.receive(callback_token, 0)

  case process.receive(duplicate_callback, 0) {
    Ok(Nil) -> Error(AdapterContractViolation(CallbackInvokedMultipleTimes))
    Error(_) ->
      case adapter_result {
        Ok(_) -> read_callback_result(callback_result, Committed)
        Error(AdapterCallbackRolledBack) ->
          read_callback_result(callback_result, RolledBack)
        Error(AdapterMissingConnection) -> Error(MissingConnection)
        Error(AdapterStatementTimeoutSetupError(message)) ->
          Error(StatementTimeoutSetupError(message))
        Error(AdapterTransactionQueryError(message)) ->
          Error(TransactionQueryError(message))
      }
  }
}

fn read_callback_result(
  callback_result: process.Subject(Result(a, b)),
  adapter_outcome: AdapterOutcome,
) -> Result(a, RunError(b)) {
  case process.receive(callback_result, 0), adapter_outcome {
    Ok(Ok(value)), Committed -> Ok(value)
    Ok(Error(err)), RolledBack -> Error(CallbackRolledBack(err))
    Ok(Error(_)), Committed ->
      Error(AdapterContractViolation(FailedCallbackCommitted))
    Ok(Ok(_)), RolledBack ->
      Error(AdapterContractViolation(SuccessfulCallbackRolledBack))
    Error(_), _ -> Error(AdapterContractViolation(CallbackNotInvoked))
  }
}

pub fn adapter_contract_error_to_string(error: AdapterContractError) -> String {
  case error {
    CallbackNotInvoked -> "callback_not_invoked"
    CallbackInvokedMultipleTimes -> "callback_invoked_multiple_times"
    FailedCallbackCommitted -> "failed_callback_committed"
    SuccessfulCallbackRolledBack -> "successful_callback_rolled_back"
  }
}
