import gleam/dict
import gleam/option
import gleam/time/timestamp
import glot_backend/auth/domain/cleanup/sessions as clean_sessions_domain
import glot_backend/system/request/context
import glot_core/auth/platform_model
import glot_core/auth/session_model
import support/integration/fixture
import support/integration/model
import support/integration/profile/auth as runner
import support/integration/store/common

pub fn clean_sessions_deletes_only_expired_rows_test() {
  let old_session =
    session_model.Session(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000d01"),
      user_id: fixture.test_user_id(),
      token: "old-session-token",
      previous_token: option.None,
      previous_token_valid_until: option.None,
      ip: option.Some("127.0.0.1"),
      os_name: option.Some(platform_model.MacOS),
      browser_name: option.Some(platform_model.Chrome),
      user_agent: option.Some("gleeunit"),
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_800_000, 0),
      token_updated_at: timestamp.from_unix_seconds_and_nanoseconds(
        1_699_999_000,
        0,
      ),
      last_activity_at: timestamp.from_unix_seconds_and_nanoseconds(
        1_699_999_000,
        0,
      ),
    )
  let recent_session =
    session_model.Session(
      ..old_session,
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000d02"),
      token: "recent-session-token",
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_950_000, 0),
      token_updated_at: timestamp.from_unix_seconds_and_nanoseconds(
        1_699_999_500,
        0,
      ),
    )
  let ctx =
    context.Context(
      ..fixture.test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    model.TestState(
      ..fixture.empty_test_state(),
      sessions: dict.from_list([
        #(common.uuid_key(old_session.id), old_session),
        #(common.uuid_key(recent_session.id), recent_session),
      ]),
      session_ids_by_token: dict.from_list([
        #(old_session.token, common.uuid_key(old_session.id)),
        #(recent_session.token, common.uuid_key(recent_session.id)),
      ]),
    )

  let #(run_result, updated_db) =
    runner.run_test_program(clean_sessions_domain.clean_sessions(ctx), ctx, db)

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.sessions, common.uuid_key(old_session.id))
    == Error(Nil)
  assert dict.get(updated_db.sessions, common.uuid_key(recent_session.id))
    == Ok(recent_session)
  assert dict.get(updated_db.session_ids_by_token, old_session.token)
    == Error(Nil)
  assert dict.get(updated_db.session_ids_by_token, recent_session.token)
    == Ok(common.uuid_key(recent_session.id))
}
