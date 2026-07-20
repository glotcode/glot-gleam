import glot_backend/system/effect/database_ports.{type DatabasePorts}
import glot_backend/system/effect/transaction/transaction_port
import support/integration/adapter/state

pub fn new(
  test_state: state.State,
  database: DatabasePorts,
) -> transaction_port.TransactionPort {
  transaction_port.new(fn(_, callback) {
    let snapshot = state.get(test_state)
    case callback(database) {
      Ok(_) -> Ok(Nil)
      Error(_) -> {
        state.put(test_state, snapshot)
        Error(transaction_port.AdapterCallbackRolledBack)
      }
    }
  })
}
