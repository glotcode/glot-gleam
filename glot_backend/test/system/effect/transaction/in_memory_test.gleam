import exception
import gleam/dict
import gleam/option
import glot_backend/system/effect/database_ports
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/transaction/transaction_port
import glot_core/snippet/snippet_model
import support/integration/adapter/service_ports
import support/integration/adapter/state
import support/integration/fixture
import support/integration/model
import support/integration/store/common

pub fn successful_transaction_commits_changes_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let test_state = state.new(fixture.state)
  use <- exception.defer(fn() { state.stop(test_state) })
  let services =
    service_ports.defaults(test_state)
    |> service_ports.with_snippet(test_state)
  let changed = snippet_model.Snippet(..fixture.snippet, title: "changed")

  let result =
    transaction_port.run(services.transaction, 1000, fn(database) {
      database_ports.snippet(database).update_snippet(changed)
    })

  assert result == Ok(Nil)
  let committed = state.get(test_state)
  let assert Ok(snippet) =
    dict.get(committed.snippets, common.uuid_key(fixture.snippet.id))
  assert snippet.title == "changed"
}

pub fn failed_transaction_restores_snapshot_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let test_state = state.new(fixture.state)
  use <- exception.defer(fn() { state.stop(test_state) })
  let services =
    service_ports.defaults(test_state)
    |> service_ports.with_snippet(test_state)
  let changed = snippet_model.Snippet(..fixture.snippet, title: "changed")

  let result =
    transaction_port.run(services.transaction, 1000, fn(database) {
      let store = database_ports.snippet(database)
      let assert Ok(Nil) = store.update_snippet(changed)
      Error("roll back")
    })

  assert result == Error(transaction_port.CallbackRolledBack("roll back"))
  let db = state.get(test_state)
  let assert Ok(snippet) =
    dict.get(db.snippets, common.uuid_key(fixture.snippet.id))
  assert snippet.title == fixture.snippet.title
}

pub fn uuid_consumption_follows_transaction_outcome_test() {
  let first = fixture.test_request_id()
  let second = fixture.test_account_id()
  let test_state =
    state.new(
      model.TestState(..fixture.empty_test_state(), next_uuids: [first, second]),
    )
  use <- exception.defer(fn() { state.stop(test_state) })
  let services = service_ports.defaults(test_state)

  let rolled_back =
    transaction_port.run(services.transaction, 1000, fn(_) {
      let consumed = state.pop_uuid(test_state)
      Error(consumed)
    })

  assert rolled_back == Error(transaction_port.CallbackRolledBack(first))
  assert state.get(test_state).next_uuids == [first, second]

  let committed =
    transaction_port.run(services.transaction, 1000, fn(_) {
      Ok(state.pop_uuid(test_state))
    })

  assert committed == Ok(first)
  assert state.get(test_state).next_uuids == [second]
}

pub fn default_ports_reject_unexpected_feature_calls_test() {
  let test_state = state.new(fixture.empty_test_state())
  use <- exception.defer(fn() { state.stop(test_state) })
  let services = service_ports.defaults(test_state)
  let store = database_ports.snippet(services.database)

  assert store.get_snippet_by_slug("unexpected")
    == Error(db_error.DbQueryError(
      "unexpected test port call: snippet.get_by_slug",
    ))
}
