import exception
import gleam/erlang/process
import gleam/option
import glot_backend/system/effect/database_ports.{type DatabasePorts}
import glot_backend/system/effect/transaction/transaction_port
import support/integration/adapter/service_ports
import support/integration/adapter/state
import support/integration/fixture

pub fn adapter_must_invoke_callback_test() {
  let port = transaction_port.new(fn(_, _) { Ok(Nil) })

  let result = transaction_port.run(port, 1000, fn(_) { Ok("callback result") })

  assert result
    == Error(transaction_port.AdapterContractViolation(
      transaction_port.CallbackNotInvoked,
    ))
}

pub fn adapter_invoking_callback_once_returns_typed_result_test() {
  with_database(fn(database) {
    let port =
      transaction_port.new(fn(_, callback) {
        let _ = callback(database)
        Ok(Nil)
      })

    let result =
      transaction_port.run(port, 1000, fn(_) { Ok("callback result") })

    assert result == Ok("callback result")
  })
}

pub fn adapter_cannot_invoke_callback_multiple_times_test() {
  with_database(fn(database) {
    let callback_invocations = process.new_subject()
    let port =
      transaction_port.new(fn(_, callback) {
        let _ = callback(database)
        let _ = callback(database)
        Ok(Nil)
      })

    let result =
      transaction_port.run(port, 1000, fn(_) {
        process.send(callback_invocations, Nil)
        Ok(Nil)
      })

    assert result
      == Error(transaction_port.AdapterContractViolation(
        transaction_port.CallbackInvokedMultipleTimes,
      ))
    assert process.receive(callback_invocations, 0) == Ok(Nil)
    assert process.receive(callback_invocations, 0) == Error(Nil)
  })
}

pub fn adapter_cannot_commit_failed_callback_test() {
  with_database(fn(database) {
    let port =
      transaction_port.new(fn(_, callback) {
        let _ = callback(database)
        Ok(Nil)
      })

    let result = transaction_port.run(port, 1000, fn(_) { Error("roll back") })

    assert result
      == Error(transaction_port.AdapterContractViolation(
        transaction_port.FailedCallbackCommitted,
      ))
  })
}

pub fn adapter_cannot_roll_back_successful_callback_test() {
  with_database(fn(database) {
    let port =
      transaction_port.new(fn(_, callback) {
        let _ = callback(database)
        Error(transaction_port.AdapterCallbackRolledBack)
      })

    let result = transaction_port.run(port, 1000, fn(_) { Ok("committed") })

    assert result
      == Error(transaction_port.AdapterContractViolation(
        transaction_port.SuccessfulCallbackRolledBack,
      ))
  })
}

fn with_database(run: fn(DatabasePorts) -> Nil) -> Nil {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let test_state = state.new(fixture.state)
  use <- exception.defer(fn() { state.stop(test_state) })
  let services = service_ports.defaults(test_state)
  run(services.database)
}
