import gleam/option
import glot_backend/admin/domain/config/auth/get as get_auth_config_domain
import glot_backend/admin/domain/config/auth/upsert as upsert_auth_config_domain
import glot_backend/admin/domain/config/availability/get as get_availability_config_domain
import glot_backend/admin/domain/config/availability/upsert as upsert_availability_config_domain
import glot_backend/admin/domain/config/cloudflare/upsert as upsert_cloudflare_config_domain
import glot_backend/admin/domain/config/debug/get as get_debug_config_domain
import glot_backend/admin/domain/config/debug/upsert as upsert_debug_config_domain
import glot_backend/admin/domain/config/docker_run/get as get_docker_run_config_domain
import glot_backend/admin/domain/config/docker_run/upsert as upsert_docker_run_config_domain
import glot_backend/admin/domain/config/email/get as get_email_config_domain
import glot_backend/admin/domain/config/email/upsert as upsert_email_config_domain
import glot_backend/admin/domain/config/rate_limit/list as get_rate_limit_policies_domain
import glot_backend/admin/domain/config/rate_limit/upsert as upsert_rate_limit_policy_domain
import glot_backend/auth/error as auth_error
import glot_backend/system/effect/error
import glot_backend/system/request/hydrated_context as request_context
import glot_core/admin/auth_config_dto
import glot_core/admin/availability_config_dto
import glot_core/admin/cloudflare_config_dto
import glot_core/admin/debug_config_dto
import glot_core/admin/docker_run_config_dto
import glot_core/admin/email_config_dto
import glot_core/admin/rate_limit_config_dto
import glot_core/auth/account_model
import glot_core/availability_mode
import glot_core/public_action
import glot_core/rate_limit
import support/integration/fixture
import support/integration/profile/admin as runner

pub fn get_rate_limit_policies_requires_admin_role_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    runner.run_test_program(
      get_rate_limit_policies_domain.get_rate_limit_policies(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_docker_run_config_requires_admin_role_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    runner.run_test_program(
      get_docker_run_config_domain.get_docker_run_config(request_context.new(
        fixture.ctx,
        fixture.state.dynamic_config,
      )),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_email_config_requires_admin_role_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    runner.run_test_program(
      get_email_config_domain.get_email_config(request_context.new(
        fixture.ctx,
        fixture.state.dynamic_config,
      )),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_auth_config_requires_admin_role_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    runner.run_test_program(
      get_auth_config_domain.get_auth_config(request_context.new(
        fixture.ctx,
        fixture.state.dynamic_config,
      )),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_debug_config_requires_admin_role_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    runner.run_test_program(
      get_debug_config_domain.get_debug_config(request_context.new(
        fixture.ctx,
        fixture.state.dynamic_config,
      )),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_availability_config_requires_admin_role_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    runner.run_test_program(
      get_availability_config_domain.get_availability_config(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn upsert_debug_config_allows_admin_role_test() {
  let fixture = fixture.admin_integration_fixture()
  let request = debug_config_dto.UpsertDebugConfigRequest(enabled: True)

  let #(run_result, _) =
    runner.run_test_program(
      upsert_debug_config_domain.upsert_debug_config(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result == Ok(debug_config_dto.DebugConfigResponse(enabled: True))
}

pub fn upsert_availability_config_allows_admin_role_test() {
  let fixture = fixture.admin_integration_fixture()
  let request =
    availability_config_dto.UpsertAvailabilityConfigRequest(
      mode: availability_mode.MaintenanceMode,
      message: "Maintenance is in progress.",
      retry_after_seconds: option.Some(300),
    )

  let #(run_result, _) =
    runner.run_test_program(
      upsert_availability_config_domain.upsert_availability_config(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result
    == Ok(availability_config_dto.AvailabilityConfigResponse(
      mode: availability_mode.MaintenanceMode,
      message: "Maintenance is in progress.",
      retry_after_seconds: option.Some(300),
    ))
}

pub fn upsert_rate_limit_policy_allows_admin_role_test() {
  let fixture = fixture.admin_integration_fixture()
  let request =
    rate_limit_config_dto.UpsertRateLimitPolicyRequest(
      action: public_action.RunAction,
      rules: [
        rate_limit_config_dto.RateLimitRule(
          match: rate_limit_config_dto.AuthenticatedMatch(account_tiers: [
            account_model.FreeTier,
          ]),
          limits: [
            rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 10),
          ],
        ),
      ],
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      upsert_rate_limit_policy_domain.upsert_rate_limit_policy(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result
    == Ok(rate_limit_config_dto.RateLimitPolicyResponse(
      action: public_action.RunAction,
      rules: request.rules,
    ))
  assert updated_db.user_action_count == 1
}

pub fn upsert_docker_run_config_allows_admin_role_test() {
  let fixture = fixture.admin_integration_fixture()
  let request =
    docker_run_config_dto.UpsertDockerRunConfigRequest(
      base_url: "https://docker-run.internal",
      access_token: "plain-token",
      default_timeout_ms: 45_000,
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      upsert_docker_run_config_domain.upsert_docker_run_config(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result
    == Ok(docker_run_config_dto.DockerRunConfigResponse(
      base_url: request.base_url,
      access_token: request.access_token,
      default_timeout_ms: request.default_timeout_ms,
    ))
  assert updated_db.user_action_count == 1
}

pub fn upsert_cloudflare_config_allows_admin_role_test() {
  let fixture = fixture.admin_integration_fixture()
  let request =
    cloudflare_config_dto.UpsertCloudflareConfigRequest(
      account_id: "cf-account-id",
      api_token: "cf-api-token",
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      upsert_cloudflare_config_domain.upsert_cloudflare_config(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result
    == Ok(cloudflare_config_dto.CloudflareConfigResponse(
      account_id: request.account_id,
      api_token: request.api_token,
    ))
  assert updated_db.user_action_count == 1
}

pub fn upsert_email_config_allows_admin_role_test() {
  let fixture = fixture.admin_integration_fixture()
  let request =
    email_config_dto.UpsertEmailConfigRequest(
      from_address: "sender@example.com",
      from_name: option.Some("Sender"),
      contact_address: option.Some("contact@example.com"),
      default_timeout_ms: 45_000,
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      upsert_email_config_domain.upsert_email_config(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result
    == Ok(email_config_dto.EmailConfigResponse(
      from_address: request.from_address,
      from_name: request.from_name,
      contact_address: request.contact_address,
      default_timeout_ms: request.default_timeout_ms,
    ))
  assert updated_db.user_action_count == 1
}

pub fn upsert_auth_config_allows_admin_role_test() {
  let fixture = fixture.admin_integration_fixture()
  let request =
    auth_config_dto.UpsertAuthConfigRequest(
      login_token_max_age: 1200,
      session_token_max_age: 172_800,
      session_idle_timeout_seconds: 86_400,
      session_cookie_max_age: 172_800,
      session_refresh_interval_seconds: 600,
      session_previous_token_grace_seconds: 90,
      session_heartbeat_interval_seconds: 120,
    )

  let #(run_result, updated_db) =
    runner.run_test_program(
      upsert_auth_config_domain.upsert_auth_config(
        request_context.new(fixture.ctx, fixture.state.dynamic_config),
        request,
      ),
      fixture.ctx,
      fixture.state,
    )

  assert run_result
    == Ok(auth_config_dto.AuthConfigResponse(
      login_token_max_age: request.login_token_max_age,
      session_token_max_age: request.session_token_max_age,
      session_idle_timeout_seconds: request.session_idle_timeout_seconds,
      session_cookie_max_age: request.session_cookie_max_age,
      session_refresh_interval_seconds: request.session_refresh_interval_seconds,
      session_previous_token_grace_seconds: request.session_previous_token_grace_seconds,
      session_heartbeat_interval_seconds: request.session_heartbeat_interval_seconds,
    ))
  assert updated_db.user_action_count == 1
}
