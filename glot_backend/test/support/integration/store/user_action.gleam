import gleam/dict
import gleam/list
import gleam/time/timestamp
import glot_core/helpers/timestamp_helpers
import support/integration/model

pub fn increment_user_action_count(db: model.TestState) -> model.TestState {
  model.TestState(
    ..db,
    user_action_count: db.user_action_count + 1,
    write_steps: ["create_user_action", ..db.write_steps],
  )
}

pub fn delete_user_actions_before(
  db: model.TestState,
  before: timestamp.Timestamp,
) -> model.TestState {
  let before_microseconds = timestamp_helpers.to_microseconds(before)
  let kept_user_actions =
    db.user_actions
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, user_action) = entry
      timestamp_helpers.to_microseconds(user_action.created_at)
      >= before_microseconds
    })
    |> dict.from_list

  model.TestState(..db, user_actions: kept_user_actions)
}
