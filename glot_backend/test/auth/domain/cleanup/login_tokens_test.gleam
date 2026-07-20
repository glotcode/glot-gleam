import gleam/dict
import gleam/option
import gleam/time/timestamp
import glot_backend/auth/domain/cleanup/login_tokens as clean_login_tokens_domain
import glot_backend/system/request/context
import glot_core/auth/login_token_model
import support/integration/fixture
import support/integration/model
import support/integration/profile/auth as runner
import support/integration/store/common

pub fn clean_login_tokens_deletes_only_old_rows_test() {
  let old_login_token =
    login_token_model.LoginToken(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000c01"),
      email: fixture.test_email_address(),
      token: "old-login-token",
      attempt_count: 0,
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
      used_at: option.None,
    )
  let recent_login_token =
    login_token_model.LoginToken(
      ..old_login_token,
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000c02"),
      token: "recent-login-token",
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
      login_tokens: dict.from_list([
        #(common.uuid_key(old_login_token.id), old_login_token),
        #(common.uuid_key(recent_login_token.id), recent_login_token),
      ]),
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      clean_login_tokens_domain.clean_login_tokens(ctx),
      ctx,
      db,
    )

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.login_tokens, common.uuid_key(old_login_token.id))
    == Error(Nil)
  assert dict.get(
      updated_db.login_tokens,
      common.uuid_key(recent_login_token.id),
    )
    == Ok(recent_login_token)
}
