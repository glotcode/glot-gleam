import gleam/option
import glot_backend/auth/domain/passkey/begin_login as begin_passkey_login_domain
import glot_backend/auth/domain/passkey/finish_login as finish_passkey_login_domain
import glot_backend/auth/error as auth_error
import glot_backend/auth/passkey/base64url
import glot_backend/system/effect/error
import glot_backend/system/request/hydrated_context as request_context
import glot_core/auth/passkey_challenge_model
import glot_core/auth/passkey_credential_model
import glot_core/auth/passkey_dto
import support/integration/fixture
import support/integration/profile/auth as runner
import support/integration/store/auth

pub fn begin_passkey_login_without_credentials_creates_anonymous_challenge_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [fixture.must_uuid("00000000-0000-0000-0000-000000000821")],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      begin_passkey_login_domain.begin_passkey_login(request_context.new(
        fixture.ctx,
        fixture.state.dynamic_config,
      )),
      fixture.ctx,
      fixture.state,
    )

  let assert Ok(response) = run_result
  assert response.challenge != ""
  assert response.rp_id == "glot.io"
  assert response.allow_credential_ids == []
  assert response.user_verification == "required"
  assert updated_db.user_action_count == 1

  let assert option.Some(challenge) =
    auth.find_passkey_challenge_by_id(updated_db, response.challenge_id)
  assert challenge.user_id == option.None
  assert challenge.flow
    == passkey_challenge_model.PasskeyAuthenticationChallenge
}

pub fn finish_passkey_login_with_valid_credential_and_anonymous_challenge_logs_user_in_test() {
  let challenge_id = fixture.must_uuid("00000000-0000-0000-0000-000000000851")
  let session_id = fixture.must_uuid("00000000-0000-0000-0000-000000000852")
  let credential =
    passkey_credential_model.PasskeyCredential(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000853"),
      user_id: fixture.test_user_id(),
      credential_id: <<1, 2, 3>>,
      cose_key: <<131, 106>>,
      sign_count: 1,
      aaguid: <<>>,
      os_name: option.None,
      browser_name: option.None,
      user_agent: option.None,
      created_at: fixture.test_timestamp(),
      updated_at: fixture.test_timestamp(),
      last_used_at: option.None,
    )
  let fixture =
    fixture.integration_fixture(
      next_uuids: [challenge_id, session_id],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let db = auth.upsert_passkey_credential(fixture.state, credential)

  let #(begin_result, challenged_db) =
    runner.run_test_program(
      begin_passkey_login_domain.begin_passkey_login(request_context.new(
        fixture.ctx,
        fixture.state.dynamic_config,
      )),
      fixture.ctx,
      db,
    )

  let assert Ok(begin_response) = begin_result
  let request =
    passkey_dto.FinishPasskeyLoginRequest(
      challenge_id: begin_response.challenge_id,
      credential_id: base64url.encode(credential.credential_id),
      authenticator_data: base64url.encode(<<4>>),
      signature: base64url.encode(<<5>>),
      client_data_json: "test-passkey-login-success",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      finish_passkey_login_domain.finish_passkey_login(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      challenged_db,
    )

  let assert Ok(session_issue) = run_result
  assert session_issue.session_token == "random"
  assert session_issue.session_cookie_max_age == 86_400
  assert auth.find_passkey_challenge_by_id(
      updated_db,
      begin_response.challenge_id,
    )
    == option.None

  let assert option.Some(updated_credential) =
    auth.find_passkey_credential_by_credential_id(
      updated_db,
      credential.credential_id,
    )
  assert updated_credential.sign_count == 2
  assert updated_credential.last_used_at
    == option.Some(fixture.test_timestamp())

  let assert option.Some(updated_user) =
    auth.find_user_by_id(updated_db, fixture.user.id)
  assert updated_user.identity.last_login_at == fixture.test_timestamp()

  let assert option.Some(new_session) =
    auth.find_session_by_token(updated_db, "random", fixture.ctx.timestamp)
  assert new_session.user_id == fixture.user.id
}

pub fn finish_passkey_login_with_unknown_credential_id_returns_invalid_assertion_test() {
  let challenge_id = fixture.must_uuid("00000000-0000-0000-0000-000000000861")
  let fixture =
    fixture.integration_fixture(
      next_uuids: [challenge_id],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(begin_result, challenged_db) =
    runner.run_test_program(
      begin_passkey_login_domain.begin_passkey_login(request_context.new(
        fixture.ctx,
        fixture.state.dynamic_config,
      )),
      fixture.ctx,
      fixture.state,
    )

  let assert Ok(begin_response) = begin_result
  let request =
    passkey_dto.FinishPasskeyLoginRequest(
      challenge_id: begin_response.challenge_id,
      credential_id: base64url.encode(<<9, 9, 9>>),
      authenticator_data: base64url.encode(<<4>>),
      signature: base64url.encode(<<5>>),
      client_data_json: "test-passkey-login-success",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      finish_passkey_login_domain.finish_passkey_login(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      challenged_db,
    )

  assert run_result == Error(error.auth(auth_error.InvalidPasskeyAssertion))
  let assert option.Some(_) =
    auth.find_passkey_challenge_by_id(updated_db, begin_response.challenge_id)
  assert auth.find_session_by_token(updated_db, "random", fixture.ctx.timestamp)
    == option.None
}

pub fn finish_passkey_login_missing_challenge_returns_not_found_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request =
    passkey_dto.FinishPasskeyLoginRequest(
      challenge_id: fixture.must_uuid("00000000-0000-0000-0000-000000000841"),
      credential_id: base64url.encode(<<1, 2, 3>>),
      authenticator_data: base64url.encode(<<4, 5, 6>>),
      signature: base64url.encode(<<7, 8, 9>>),
      client_data_json: "{}",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      finish_passkey_login_domain.finish_passkey_login(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Error(error.auth(auth_error.PasskeyChallengeNotFound))
  assert updated_db.write_steps == fixture.state.write_steps
}
