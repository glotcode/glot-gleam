import gleam/dict
import gleam/list
import gleam/option
import glot_backend/auth/domain/passkey/begin_registration as begin_passkey_registration_domain
import glot_backend/auth/domain/passkey/finish_registration as finish_passkey_registration_domain
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

pub fn begin_passkey_registration_creates_challenge_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [fixture.must_uuid("00000000-0000-0000-0000-000000000801")],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      begin_passkey_registration_domain.begin_passkey_registration(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
      ),
      fixture.ctx,
      fixture.state,
    )

  let assert Ok(response) = run_result
  assert response.challenge != ""
  assert response.rp_id == "glot.io"
  assert response.user_name == "user@example.com"
  assert response.user_display_name == "user"
  assert response.user_verification == "required"
  assert response.exclude_credential_ids == []
  assert response.algorithm_ids == [-7, -257]
  assert response.attestation == "none"
  assert list.length(dict.to_list(updated_db.passkey_challenges)) == 1
  assert updated_db.user_action_count == 1

  let assert option.Some(challenge) =
    auth.find_passkey_challenge_by_id(updated_db, response.challenge_id)
  assert challenge.user_id == option.Some(fixture.user.id)
  assert challenge.flow == passkey_challenge_model.PasskeyRegistrationChallenge
}

pub fn begin_passkey_registration_includes_existing_credential_ids_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [fixture.must_uuid("00000000-0000-0000-0000-000000000811")],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let credential =
    passkey_credential_model.PasskeyCredential(
      id: fixture.must_uuid("00000000-0000-0000-0000-000000000812"),
      user_id: fixture.user.id,
      credential_id: <<1, 2, 3>>,
      cose_key: <<131, 106>>,
      sign_count: 0,
      aaguid: <<>>,
      os_name: option.None,
      browser_name: option.None,
      user_agent: option.None,
      created_at: fixture.test_timestamp(),
      updated_at: fixture.test_timestamp(),
      last_used_at: option.None,
    )
  let db = auth.upsert_passkey_credential(fixture.state, credential)

  let #(run_result, _) =
    runner.run_test_program(
      begin_passkey_registration_domain.begin_passkey_registration(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
      ),
      fixture.ctx,
      db,
    )

  let assert Ok(response) = run_result
  assert response.exclude_credential_ids == [base64url.encode(<<1, 2, 3>>)]
}

pub fn finish_passkey_registration_missing_challenge_returns_not_found_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request =
    passkey_dto.FinishPasskeyRegistrationRequest(
      challenge_id: fixture.must_uuid("00000000-0000-0000-0000-000000000831"),
      attestation_object: base64url.encode(<<1>>),
      client_data_json: "{}",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      finish_passkey_registration_domain.finish_passkey_registration(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Error(error.auth(auth_error.PasskeyChallengeNotFound))
  assert updated_db.write_steps == fixture.state.write_steps
}
