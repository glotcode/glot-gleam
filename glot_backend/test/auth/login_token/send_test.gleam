import gleam/option
import glot_backend/auth/domain/login_token/send as send_login_token_domain
import glot_backend/system/effect/error
import glot_backend/system/effect/error/policy_error
import glot_backend/system/request/hydrated_context as request_context
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/auth/login_token_dto
import glot_core/public_action
import support/integration/fixture
import support/integration/profile/auth as runner

pub fn send_login_token_for_suspended_user_returns_account_state_error_test() {
  let fixture =
    fixture.suspended_integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request = login_token_dto.LoginTokenRequest(email: fixture.user.email)

  let #(run_result, db) =
    runner.run_test_program(
      send_login_token_domain.send_login_token(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result
    == Error(
      error.policy(policy_error.ForbiddenAccountState(
        action: api_action.public(public_action.SendLoginTokenAction),
        account_state: account_model.Suspended,
      )),
    )
  assert db.write_steps == []
}
