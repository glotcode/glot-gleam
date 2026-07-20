import gleam/dict
import gleam/list
import gleam/option
import glot_backend/auth/domain/login_token/login as login_domain
import glot_backend/auth/domain/login_token/send as send_login_token_domain
import glot_backend/auth/domain/session/issue as session_issue_domain
import glot_backend/auth/error as auth_error
import glot_backend/system/effect/error
import glot_backend/system/effect/error/policy_error
import glot_backend/system/request/context
import glot_backend/system/request/hydrated_context as request_context
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/auth/login_dto
import glot_core/auth/login_token_dto
import glot_core/auth/login_token_model
import glot_core/public_action
import support/integration/fixture
import support/integration/model
import support/integration/profile/auth as runner
import support/integration/store/common

pub fn login_creates_account_user_and_session_in_foreign_key_order_test() {
  let login_token =
    login_token_model.LoginToken(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000501"),
      email: fixture.test_email_address(),
      token: "login-token",
      attempt_count: 0,
      created_at: fixture.test_timestamp(),
      used_at: option.None,
    )
  let db =
    model.TestState(
      ..fixture.empty_test_state(),
      login_tokens: dict.from_list([
        #(common.uuid_key(login_token.id), login_token),
      ]),
      next_uuids: [
        fixture.must_uuid("00000000-0000-0000-0000-000000000502"),
        fixture.must_uuid("00000000-0000-0000-0000-000000000503"),
        fixture.must_uuid("00000000-0000-0000-0000-000000000504"),
      ],
    )
  let ctx =
    context.Context(
      ..fixture.test_context(),
      request_id: fixture.test_request_id(),
      timestamp: fixture.test_timestamp(),
      client_info: context.ClientInfo(
        session_token: option.None,
        ip: option.Some("127.0.0.1"),
        user_agent: option.Some("gleeunit"),
        referrer: option.None,
      ),
    )
  let request =
    login_dto.LoginRequest(
      email: fixture.test_email_address(),
      token: "login-token",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      login_domain.login(request_context.new(ctx, db.dynamic_config), request),
      ctx,
      db,
    )

  assert run_result
    == Ok(session_issue_domain.SessionIssueResult(
      session_token: "random",
      session_cookie_max_age: 86_400,
    ))
  assert list.reverse(updated_db.write_steps)
    == [
      "update_login_token",
      "create_account",
      "create_user",
      "create_session",
      "create_user_action",
    ]
  let assert Ok(updated_login_token) =
    dict.get(updated_db.login_tokens, common.uuid_key(login_token.id))
  assert updated_login_token.attempt_count == 1
  assert updated_login_token.used_at == option.Some(ctx.timestamp)
}

pub fn invalid_login_increments_all_valid_token_attempt_counts_test() {
  let current_token =
    login_token_model.LoginToken(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000511"),
      email: fixture.test_email_address(),
      token: "current-token",
      attempt_count: 2,
      created_at: fixture.test_timestamp(),
      used_at: option.None,
    )
  let previous_token =
    login_token_model.LoginToken(
      ..current_token,
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000512"),
      token: "previous-token",
      attempt_count: 4,
    )
  let db =
    model.TestState(
      ..fixture.empty_test_state(),
      login_tokens: dict.from_list([
        #(common.uuid_key(current_token.id), current_token),
        #(common.uuid_key(previous_token.id), previous_token),
      ]),
    )
  let request =
    login_dto.LoginRequest(
      email: fixture.test_email_address(),
      token: "wrong-token",
    )
  let ctx = fixture.login_test_context()

  let #(run_result, updated_db) =
    runner.run_test_program(
      login_domain.login(request_context.new(ctx, db.dynamic_config), request),
      ctx,
      db,
    )

  assert run_result == Error(error.auth(auth_error.InvalidLoginToken))
  let assert Ok(updated_current_token) =
    dict.get(updated_db.login_tokens, common.uuid_key(current_token.id))
  let assert Ok(updated_previous_token) =
    dict.get(updated_db.login_tokens, common.uuid_key(previous_token.id))
  assert updated_current_token.attempt_count == 5
  assert updated_previous_token.attempt_count == 5
  assert list.reverse(updated_db.write_steps)
    == ["update_login_token", "update_login_token"]
}

pub fn login_at_shared_attempt_limit_is_rejected_without_session_test() {
  let login_token =
    login_token_model.LoginToken(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000521"),
      email: fixture.test_email_address(),
      token: "login-token",
      attempt_count: 10,
      created_at: fixture.test_timestamp(),
      used_at: option.None,
    )
  let db =
    model.TestState(
      ..fixture.empty_test_state(),
      login_tokens: dict.from_list([
        #(common.uuid_key(login_token.id), login_token),
      ]),
    )
  let request =
    login_dto.LoginRequest(
      email: fixture.test_email_address(),
      token: "login-token",
    )
  let ctx = fixture.login_test_context()

  let #(run_result, updated_db) =
    runner.run_test_program(
      login_domain.login(request_context.new(ctx, db.dynamic_config), request),
      ctx,
      db,
    )

  assert run_result == Error(error.auth(auth_error.InvalidLoginToken))
  assert updated_db.write_steps == []
  assert dict.is_empty(updated_db.accounts)
  assert dict.is_empty(updated_db.users)
  assert dict.is_empty(updated_db.sessions)
}

pub fn new_login_token_inherits_shared_attempt_count_test() {
  let user_action_id = fixture.must_uuid("00000000-0000-0000-0000-000000000531")
  let login_token_id = fixture.must_uuid("00000000-0000-0000-0000-000000000532")
  let job_id = fixture.must_uuid("00000000-0000-0000-0000-000000000533")
  let fixture =
    fixture.integration_fixture(
      next_uuids: [user_action_id, login_token_id, job_id],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let existing_token =
    login_token_model.LoginToken(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000534"),
      email: fixture.user.email,
      token: "existing-token",
      attempt_count: 7,
      created_at: fixture.ctx.timestamp,
      used_at: option.None,
    )
  let db =
    model.TestState(
      ..fixture.state,
      login_tokens: dict.from_list([
        #(common.uuid_key(existing_token.id), existing_token),
      ]),
    )
  let request = login_token_dto.LoginTokenRequest(email: fixture.user.email)

  let #(run_result, updated_db) =
    runner.run_test_program(
      send_login_token_domain.send_login_token(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      db,
    )

  assert run_result == Ok(Nil)
  let assert Ok(new_token) =
    dict.get(updated_db.login_tokens, common.uuid_key(login_token_id))
  assert new_token.attempt_count == 7
}

pub fn login_for_suspended_user_returns_account_state_error_test() {
  let login_token =
    login_token_model.LoginToken(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000601"),
      email: fixture.test_email_address(),
      token: "login-token",
      attempt_count: 0,
      created_at: fixture.test_timestamp(),
      used_at: option.None,
    )
  let fixture =
    fixture.suspended_integration_fixture(
      next_uuids: [
        fixture.must_uuid("00000000-0000-0000-0000-000000000602"),
        fixture.must_uuid("00000000-0000-0000-0000-000000000603"),
        fixture.must_uuid("00000000-0000-0000-0000-000000000604"),
      ],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let db =
    model.TestState(
      ..fixture.state,
      login_tokens: dict.from_list([
        #(common.uuid_key(login_token.id), login_token),
      ]),
    )
  let ctx =
    context.Context(
      ..fixture.ctx,
      client_info: context.ClientInfo(
        session_token: option.None,
        ip: option.Some("127.0.0.1"),
        user_agent: option.Some("gleeunit"),
        referrer: option.None,
      ),
    )
  let request =
    login_dto.LoginRequest(
      email: fixture.test_email_address(),
      token: "login-token",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      login_domain.login(request_context.new(ctx, db.dynamic_config), request),
      ctx,
      db,
    )

  assert run_result
    == Error(
      error.policy(policy_error.ForbiddenAccountState(
        action: api_action.public(public_action.LoginAction),
        account_state: account_model.Suspended,
      )),
    )
  assert updated_db.write_steps == []
}
