import gleam/dict
import gleam/option
import gleam/time/timestamp
import glot_backend/system/request/context
import glot_backend/user_action/domain/cleanup as clean_user_actions_domain
import glot_core/api_action
import glot_core/public_action
import glot_core/user_action
import support/integration/fixture
import support/integration/model
import support/integration/profile/user_action as runner
import support/integration/store/common

pub fn clean_user_actions_deletes_only_old_rows_test() {
  let old_action =
    user_action.UserAction(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000b01"),
      request_id: fixture.test_request_id(),
      action: api_action.public(public_action.LoginAction),
      ip: option.Some("127.0.0.1"),
      user_id: option.None,
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
    )
  let recent_action =
    user_action.UserAction(
      ..old_action,
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000b02"),
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0),
    )
  let ctx =
    context.Context(
      ..fixture.test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    model.TestState(
      ..fixture.empty_test_state(),
      user_actions: dict.from_list([
        #(common.uuid_key(old_action.id), old_action),
        #(common.uuid_key(recent_action.id), recent_action),
      ]),
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      clean_user_actions_domain.clean_user_actions(ctx),
      ctx,
      db,
    )

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.user_actions, common.uuid_key(old_action.id))
    == Error(Nil)
  assert dict.get(updated_db.user_actions, common.uuid_key(recent_action.id))
    == Ok(recent_action)
}
