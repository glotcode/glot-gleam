import gleam/dict
import gleam/list
import gleam/time/timestamp
import glot_core/helpers/timestamp_helpers
import support/integration/model

pub fn delete_run_logs_before(
  db: model.TestState,
  before: timestamp.Timestamp,
) -> model.TestState {
  let before_microseconds = timestamp_helpers.to_microseconds(before)
  let kept_run_logs =
    db.run_logs
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, run_log) = entry
      timestamp_helpers.to_microseconds(run_log.created_at)
      >= before_microseconds
    })
    |> dict.from_list

  model.TestState(..db, run_logs: kept_run_logs)
}
