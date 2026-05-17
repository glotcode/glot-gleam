import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/order
import gleam/regexp
import gleam/string
import gleam/time/timestamp
import gleeunit
import glot_backend/app_config
import glot_backend/context
import glot_backend/domain/account/cancel_delete_account_domain
import glot_backend/domain/account/schedule_delete_account_domain
import glot_backend/domain/admin/get_auth_config_domain
import glot_backend/domain/admin/get_availability_config_domain
import glot_backend/domain/admin/get_debug_config_domain
import glot_backend/domain/admin/get_docker_run_config_domain
import glot_backend/domain/admin/get_email_config_domain
import glot_backend/domain/admin/get_rate_limit_policies_domain
import glot_backend/domain/admin/upsert_auth_config_domain
import glot_backend/domain/admin/upsert_availability_config_domain
import glot_backend/domain/admin/upsert_cloudflare_config_domain
import glot_backend/domain/admin/upsert_debug_config_domain
import glot_backend/domain/admin/upsert_docker_run_config_domain
import glot_backend/domain/admin/upsert_email_config_domain
import glot_backend/domain/admin/upsert_rate_limit_policy_domain
import glot_backend/domain/auth/login_domain
import glot_backend/domain/auth/refresh_session_domain
import glot_backend/domain/auth/send_login_token_domain
import glot_backend/domain/cleanup/clean_jobs_domain
import glot_backend/domain/cleanup/clean_login_tokens_domain
import glot_backend/domain/cleanup/clean_run_log_domain
import glot_backend/domain/cleanup/clean_user_actions_domain
import glot_backend/domain/job/job_manager_domain
import glot_backend/domain/job/periodic_job_manager_domain
import glot_backend/domain/run_code/get_language_version_domain
import glot_backend/domain/shared/session_domain
import glot_backend/domain/snippet/create_snippet_domain
import glot_backend/domain/snippet/update_snippet_domain
import glot_backend/dynamic_config
import glot_backend/effect/admin_log/admin_log_algebra
import glot_backend/effect/analytics/analytics_algebra
import glot_backend/effect/api_log/api_log_algebra
import glot_backend/effect/app_config/app_config_algebra
import glot_backend/effect/auth/auth_algebra
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/docker_run/docker_run_algebra
import glot_backend/effect/email/email_algebra
import glot_backend/effect/email_template/email_template_algebra
import glot_backend/effect/error
import glot_backend/effect/error/auth_error
import glot_backend/effect/error/infra_error
import glot_backend/effect/error/policy_error
import glot_backend/effect/error/resource_error
import glot_backend/effect/error/run_request_error
import glot_backend/effect/get_language_version/get_language_version_algebra
import glot_backend/effect/job/job_algebra
import glot_backend/effect/job_log/job_log_algebra
import glot_backend/effect/job_type_policy/job_type_policy_algebra
import glot_backend/effect/page_log/page_log_algebra
import glot_backend/effect/pageview_log/pageview_log_algebra
import glot_backend/effect/periodic_job/periodic_job_algebra
import glot_backend/effect/program_types
import glot_backend/effect/run_log/run_log_algebra
import glot_backend/effect/snippet/snippet_algebra
import glot_backend/effect/user_action/user_action_algebra
import glot_backend/email_template
import glot_core/admin/auth_config_dto
import glot_core/admin/availability_config_dto
import glot_core/admin/cloudflare_config_dto
import glot_core/admin/debug_config_dto
import glot_core/admin/docker_run_config_dto
import glot_core/admin/email_config_dto
import glot_core/admin/rate_limit_config_dto
import glot_core/api_action
import glot_core/auth/account_model
import glot_core/auth/login_dto
import glot_core/auth/login_token_dto
import glot_core/auth/login_token_model
import glot_core/auth/refresh_session_dto
import glot_core/auth/session_model
import glot_core/auth/user_model
import glot_core/availability_mode
import glot_core/email/email_address_model
import glot_core/helpers/timestamp_helpers
import glot_core/job/job_model
import glot_core/language
import glot_core/pagination_model
import glot_core/periodic_job/periodic_job_model
import glot_core/public_action
import glot_core/rate_limit
import glot_core/run
import glot_core/run_log_model
import glot_core/snippet/snippet_dto
import glot_core/snippet/snippet_model
import glot_core/snippet/snippet_spam
import glot_core/user_action
import glot_core/validation_error
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn get_session_without_token_returns_none_test() {
  let ctx = test_context()

  let #(run_result, _) =
    run_test_program(session_domain.get_session(ctx), ctx, empty_test_db())

  assert run_result == Ok(option.None)
}

pub fn refresh_session_rotates_token_with_previous_token_grace_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = add_seconds(test_timestamp(), 301)
  let ctx = context.Context(..fixture.ctx, timestamp: now)

  let #(run_result, db) =
    run_test_program(
      refresh_session_domain.refresh_session(ctx),
      ctx,
      fixture.db,
    )

  assert run_result
    == Ok(refresh_session_domain.RefreshSessionResult(
      session_token: "random",
      session_cookie_max_age: 86_400,
      response: refresh_session_dto.RefreshSessionResponse(
        next_heartbeat_in_seconds: 60,
      ),
    ))

  let assert Ok(session) = dict.get(db.sessions, uuid_key(test_session_id()))
  assert session.token == "random"
  assert session.previous_token == option.Some("session-token")
  assert session.previous_token_valid_until == option.Some(add_seconds(now, 60))
  assert session.token_updated_at == now

  let current_lookup = find_hydrated_session(db, "random", now)
  let previous_lookup = find_hydrated_session(db, "session-token", now)
  assert current_lookup != option.None
  assert previous_lookup != option.None
}

pub fn refresh_session_is_noop_when_rotated_too_recently_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = add_seconds(test_timestamp(), 120)
  let ctx = context.Context(..fixture.ctx, timestamp: now)

  let #(run_result, db) =
    run_test_program(
      refresh_session_domain.refresh_session(ctx),
      ctx,
      fixture.db,
    )

  assert run_result
    == Ok(refresh_session_domain.RefreshSessionResult(
      session_token: "session-token",
      session_cookie_max_age: 86_400,
      response: refresh_session_dto.RefreshSessionResponse(
        next_heartbeat_in_seconds: 60,
      ),
    ))

  let assert Ok(session) = dict.get(db.sessions, uuid_key(test_session_id()))
  assert session.token == "session-token"
  assert session.previous_token == option.None
  assert session.previous_token_valid_until == option.None
  assert session.token_updated_at == test_timestamp()
}

pub fn get_session_accepts_previous_token_within_grace_window_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = add_seconds(test_timestamp(), 30)
  let rotated_session =
    session_model.Session(
      ..fixture.session,
      token: "current-token",
      previous_token: option.Some("session-token"),
      previous_token_valid_until: option.Some(add_seconds(test_timestamp(), 60)),
      token_updated_at: test_timestamp(),
    )
  let db =
    TestDb(
      ..fixture.db,
      sessions: dict.from_list([
        #(uuid_key(rotated_session.id), rotated_session),
      ]),
      session_ids_by_token: dict.from_list([
        #(rotated_session.token, uuid_key(rotated_session.id)),
      ]),
    )
  let ctx =
    context.Context(
      ..fixture.ctx,
      timestamp: now,
      client_info: context.ClientInfo(
        ..fixture.ctx.client_info,
        session_token: option.Some("session-token"),
      ),
    )

  let #(run_result, _) =
    run_test_program(session_domain.get_session(ctx), ctx, db)

  let assert Ok(option.Some(session)) = run_result
  assert session.identity.id == rotated_session.id
  assert session.identity.token == "current-token"
}

pub fn get_session_rejects_previous_token_after_grace_window_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = add_seconds(test_timestamp(), 61)
  let rotated_session =
    session_model.Session(
      ..fixture.session,
      token: "current-token",
      previous_token: option.Some("session-token"),
      previous_token_valid_until: option.Some(add_seconds(test_timestamp(), 60)),
      token_updated_at: test_timestamp(),
    )
  let db =
    TestDb(
      ..fixture.db,
      sessions: dict.from_list([
        #(uuid_key(rotated_session.id), rotated_session),
      ]),
      session_ids_by_token: dict.from_list([
        #(rotated_session.token, uuid_key(rotated_session.id)),
      ]),
    )
  let ctx =
    context.Context(
      ..fixture.ctx,
      timestamp: now,
      client_info: context.ClientInfo(
        ..fixture.ctx.client_info,
        session_token: option.Some("session-token"),
      ),
    )

  let #(run_result, _) =
    run_test_program(session_domain.get_session(ctx), ctx, db)

  assert run_result == Ok(option.None)
}

pub fn refresh_session_uses_configured_heartbeat_cadence_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let auth_config =
    dynamic_config.AuthConfig(
      login_token_max_age: 900,
      session_token_max_age: 86_400,
      session_cookie_max_age: 86_400,
      session_refresh_interval_seconds: 300,
      session_previous_token_grace_seconds: 60,
      session_heartbeat_interval_seconds: 17,
    )
  let db =
    TestDb(
      ..fixture.db,
      dynamic_config: dynamic_config.DynamicConfig(
        ..fixture.db.dynamic_config,
        auth: auth_config,
      ),
    )
  let now = add_seconds(test_timestamp(), 301)
  let ctx = context.Context(..fixture.ctx, timestamp: now)

  let #(run_result, _) =
    run_test_program(refresh_session_domain.refresh_session(ctx), ctx, db)

  assert run_result
    == Ok(refresh_session_domain.RefreshSessionResult(
      session_token: "random",
      session_cookie_max_age: 86_400,
      response: refresh_session_dto.RefreshSessionResponse(
        next_heartbeat_in_seconds: 17,
      ),
    ))
}

pub fn refresh_session_rejects_expired_previous_token_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = add_seconds(test_timestamp(), 61)
  let rotated_session =
    session_model.Session(
      ..fixture.session,
      token: "current-token",
      previous_token: option.Some("session-token"),
      previous_token_valid_until: option.Some(add_seconds(test_timestamp(), 60)),
      token_updated_at: test_timestamp(),
    )
  let db =
    TestDb(
      ..fixture.db,
      sessions: dict.from_list([
        #(uuid_key(rotated_session.id), rotated_session),
      ]),
      session_ids_by_token: dict.from_list([
        #(rotated_session.token, uuid_key(rotated_session.id)),
      ]),
    )
  let ctx =
    context.Context(
      ..fixture.ctx,
      timestamp: now,
      client_info: context.ClientInfo(
        ..fixture.ctx.client_info,
        session_token: option.Some("session-token"),
      ),
    )

  let #(run_result, _) =
    run_test_program(refresh_session_domain.refresh_session(ctx), ctx, db)

  assert run_result == Error(error.auth(auth_error.SessionNotFound))
}

pub fn rate_limit_policy_prefers_tier_specific_rule_test() {
  let policy =
    dynamic_config.RateLimitPolicy(rules: [
      dynamic_config.RateLimitRule(
        match: dynamic_config.AnonymousMatch,
        limits: [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 2)],
      ),
      dynamic_config.RateLimitRule(
        match: dynamic_config.AuthenticatedMatch(account_tiers: option.None),
        limits: [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 5)],
      ),
      dynamic_config.RateLimitRule(
        match: dynamic_config.AuthenticatedMatch(
          account_tiers: option.Some([
            account_model.FreeTier,
          ]),
        ),
        limits: [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 9)],
      ),
    ])

  assert dynamic_config.select_rate_limits(
      policy,
      dynamic_config.AuthenticatedActor(account_tier: account_model.FreeTier),
    )
    == [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 9)]
}

pub fn app_config_decodes_docker_run_config_test() {
  let assert Ok(config) =
    dynamic_config.from_entries([
      app_config.AppConfigEntry(
        namespace: "docker_run",
        key: "base_url",
        value: "\"https://docker-run.internal\"",
      ),
      app_config.AppConfigEntry(
        namespace: "docker_run",
        key: "access_token",
        value: "\"plain-token\"",
      ),
    ])

  assert dynamic_config.docker_run_config(config)
    == option.Some(dynamic_config.DockerRunConfig(
      base_url: "https://docker-run.internal",
      access_token: "plain-token",
    ))
}

pub fn app_config_decodes_cloudflare_config_test() {
  let assert Ok(config) =
    dynamic_config.from_entries([
      app_config.AppConfigEntry(
        namespace: "cloudflare",
        key: "account_id",
        value: "\"cf-account-id\"",
      ),
      app_config.AppConfigEntry(
        namespace: "cloudflare",
        key: "api_token",
        value: "\"cf-api-token\"",
      ),
    ])

  assert dynamic_config.cloudflare_config(config)
    == option.Some(dynamic_config.CloudflareConfig(
      account_id: "cf-account-id",
      api_token: "cf-api-token",
    ))
}

pub fn app_config_decodes_email_config_test() {
  let assert Ok(config) =
    dynamic_config.from_entries([
      app_config.AppConfigEntry(
        namespace: "email",
        key: "from_address",
        value: "\"sender@example.com\"",
      ),
      app_config.AppConfigEntry(
        namespace: "email",
        key: "from_name",
        value: "\"Sender\"",
      ),
    ])

  assert dynamic_config.email_config(config)
    == dynamic_config.EmailConfig(
      from_address: "sender@example.com",
      from_name: option.Some("Sender"),
    )
}

pub fn app_config_uses_default_email_config_test() {
  let assert Ok(config) = dynamic_config.from_entries([])

  assert dynamic_config.email_config(config)
    == dynamic_config.EmailConfig(
      from_address: "glot@glot.io",
      from_name: option.Some("glot"),
    )
}

pub fn app_config_uses_default_auth_config_test() {
  let assert Ok(config) = dynamic_config.from_entries([])

  assert dynamic_config.auth_config(config)
    == dynamic_config.AuthConfig(
      login_token_max_age: 900,
      session_token_max_age: 86_400,
      session_cookie_max_age: 86_400,
      session_refresh_interval_seconds: 300,
      session_previous_token_grace_seconds: 60,
      session_heartbeat_interval_seconds: 60,
    )
}

pub fn app_config_uses_default_debug_config_test() {
  let assert Ok(config) = dynamic_config.from_entries([])

  assert dynamic_config.debug_config(config)
    == dynamic_config.DebugConfig(enabled: False)
}

pub fn rate_limit_policy_matches_free_plus_rule_test() {
  let policy =
    dynamic_config.RateLimitPolicy(rules: [
      dynamic_config.RateLimitRule(
        match: dynamic_config.AuthenticatedMatch(account_tiers: option.None),
        limits: [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 5)],
      ),
      dynamic_config.RateLimitRule(
        match: dynamic_config.AuthenticatedMatch(
          account_tiers: option.Some([
            account_model.FreePlusTier,
          ]),
        ),
        limits: [
          rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 12),
        ],
      ),
    ])

  assert dynamic_config.select_rate_limits(
      policy,
      dynamic_config.AuthenticatedActor(
        account_tier: account_model.FreePlusTier,
      ),
    )
    == [rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 12)]
}

pub fn rate_limit_policy_falls_back_to_anonymous_rule_test() {
  let policy =
    dynamic_config.RateLimitPolicy(rules: [
      dynamic_config.RateLimitRule(
        match: dynamic_config.AnonymousMatch,
        limits: [rate_limit.RateLimit(unit: rate_limit.Hour, max_requests: 10)],
      ),
    ])

  assert dynamic_config.select_rate_limits(
      policy,
      dynamic_config.AnonymousActor,
    )
    == [rate_limit.RateLimit(unit: rate_limit.Hour, max_requests: 10)]
}

pub fn get_rate_limit_policies_requires_admin_role_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    run_test_program(
      get_rate_limit_policies_domain.get_rate_limit_policies(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_docker_run_config_requires_admin_role_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    run_test_program(
      get_docker_run_config_domain.get_docker_run_config(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_email_config_requires_admin_role_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    run_test_program(
      get_email_config_domain.get_email_config(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_auth_config_requires_admin_role_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    run_test_program(
      get_auth_config_domain.get_auth_config(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_debug_config_requires_admin_role_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    run_test_program(
      get_debug_config_domain.get_debug_config(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn get_availability_config_requires_admin_role_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )

  let #(run_result, _) =
    run_test_program(
      get_availability_config_domain.get_availability_config(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Error(error.auth(auth_error.AdminRequired))
}

pub fn upsert_debug_config_allows_admin_role_test() {
  let fixture = admin_integration_fixture()
  let request = debug_config_dto.UpsertDebugConfigRequest(enabled: True)

  let #(run_result, _) =
    run_test_program(
      upsert_debug_config_domain.upsert_debug_config(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Ok(debug_config_dto.DebugConfigResponse(enabled: True))
}

pub fn upsert_availability_config_allows_admin_role_test() {
  let fixture = admin_integration_fixture()
  let request =
    availability_config_dto.UpsertAvailabilityConfigRequest(
      mode: availability_mode.MaintenanceMode,
      message: "Maintenance is in progress.",
      retry_after_seconds: option.Some(300),
    )

  let #(run_result, _) =
    run_test_program(
      upsert_availability_config_domain.upsert_availability_config(
        fixture.ctx,
        request,
      ),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Ok(availability_config_dto.AvailabilityConfigResponse(
      mode: availability_mode.MaintenanceMode,
      message: "Maintenance is in progress.",
      retry_after_seconds: option.Some(300),
    ))
}

pub fn upsert_rate_limit_policy_allows_admin_role_test() {
  let fixture = admin_integration_fixture()
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
    run_test_program(
      upsert_rate_limit_policy_domain.upsert_rate_limit_policy(
        fixture.ctx,
        request,
      ),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Ok(rate_limit_config_dto.RateLimitPolicyResponse(
      action: public_action.RunAction,
      rules: request.rules,
    ))
  assert updated_db.user_action_count == 1
}

pub fn upsert_docker_run_config_allows_admin_role_test() {
  let fixture = admin_integration_fixture()
  let request =
    docker_run_config_dto.UpsertDockerRunConfigRequest(
      base_url: "https://docker-run.internal",
      access_token: "plain-token",
    )

  let #(run_result, updated_db) =
    run_test_program(
      upsert_docker_run_config_domain.upsert_docker_run_config(
        fixture.ctx,
        request,
      ),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Ok(docker_run_config_dto.DockerRunConfigResponse(
      base_url: request.base_url,
      access_token: request.access_token,
    ))
  assert updated_db.user_action_count == 1
}

pub fn upsert_cloudflare_config_allows_admin_role_test() {
  let fixture = admin_integration_fixture()
  let request =
    cloudflare_config_dto.UpsertCloudflareConfigRequest(
      account_id: "cf-account-id",
      api_token: "cf-api-token",
    )

  let #(run_result, updated_db) =
    run_test_program(
      upsert_cloudflare_config_domain.upsert_cloudflare_config(
        fixture.ctx,
        request,
      ),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Ok(cloudflare_config_dto.CloudflareConfigResponse(
      account_id: request.account_id,
      api_token: request.api_token,
    ))
  assert updated_db.user_action_count == 1
}

pub fn upsert_email_config_allows_admin_role_test() {
  let fixture = admin_integration_fixture()
  let request =
    email_config_dto.UpsertEmailConfigRequest(
      from_address: "sender@example.com",
      from_name: option.Some("Sender"),
    )

  let #(run_result, updated_db) =
    run_test_program(
      upsert_email_config_domain.upsert_email_config(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Ok(email_config_dto.EmailConfigResponse(
      from_address: request.from_address,
      from_name: request.from_name,
    ))
  assert updated_db.user_action_count == 1
}

pub fn upsert_auth_config_allows_admin_role_test() {
  let fixture = admin_integration_fixture()
  let request =
    auth_config_dto.UpsertAuthConfigRequest(
      login_token_max_age: 1200,
      session_token_max_age: 172_800,
      session_cookie_max_age: 172_800,
      session_refresh_interval_seconds: 600,
      session_previous_token_grace_seconds: 90,
      session_heartbeat_interval_seconds: 120,
    )

  let #(run_result, updated_db) =
    run_test_program(
      upsert_auth_config_domain.upsert_auth_config(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Ok(auth_config_dto.AuthConfigResponse(
      login_token_max_age: request.login_token_max_age,
      session_token_max_age: request.session_token_max_age,
      session_cookie_max_age: request.session_cookie_max_age,
      session_refresh_interval_seconds: request.session_refresh_interval_seconds,
      session_previous_token_grace_seconds: request.session_previous_token_grace_seconds,
      session_heartbeat_interval_seconds: request.session_heartbeat_interval_seconds,
    ))
  assert updated_db.user_action_count == 1
}

pub fn get_session_with_missing_db_session_returns_none_test() {
  let ctx =
    context.Context(
      ..test_context(),
      client_info: context.ClientInfo(
        session_token: option.Some("missing-session-token"),
        ip: option.None,
        user_agent: option.None,
        referrer: option.None,
      ),
    )

  let #(run_result, _) =
    run_test_program(session_domain.get_session(ctx), ctx, empty_test_db())

  assert run_result == Ok(option.None)
}

pub fn require_session_without_token_returns_missing_token_error_test() {
  let ctx = test_context()

  let #(run_result, _) =
    run_test_program(session_domain.require_session(ctx), ctx, empty_test_db())

  assert run_result == Error(error.auth(auth_error.MissingSessionToken))
}

pub fn require_session_with_missing_db_session_returns_not_found_error_test() {
  let ctx =
    context.Context(
      ..test_context(),
      client_info: context.ClientInfo(
        session_token: option.Some("missing-session-token"),
        ip: option.None,
        user_agent: option.None,
        referrer: option.None,
      ),
    )

  let #(run_result, _) =
    run_test_program(session_domain.require_session(ctx), ctx, empty_test_db())

  assert run_result == Error(error.auth(auth_error.SessionNotFound))
}

pub fn get_language_version_without_session_reaches_docker_run_test() {
  let ctx = test_context()
  let request = run.GetLanguageVersionRequest(language: language.Python)

  let #(run_result, db) =
    run_test_program(
      get_language_version_domain.get_language_version(ctx, request),
      ctx,
      empty_test_db(),
    )

  assert run_result
    == Error(error.run_request_error(run_request_error.ServerRunRequestError))
  assert db.write_steps == []
}

pub fn login_creates_account_user_and_session_in_foreign_key_order_test() {
  let login_token =
    login_token_model.LoginToken(
      id: must_uuid("00000000-0000-0000-0000-000000000501"),
      email: test_email_address(),
      token: "login-token",
      created_at: test_timestamp(),
      used_at: option.None,
    )
  let db =
    TestDb(
      ..empty_test_db(),
      login_tokens: dict.from_list([#(uuid_key(login_token.id), login_token)]),
      next_uuids: [
        must_uuid("00000000-0000-0000-0000-000000000502"),
        must_uuid("00000000-0000-0000-0000-000000000503"),
        must_uuid("00000000-0000-0000-0000-000000000504"),
      ],
    )
  let ctx =
    context.Context(
      ..test_context(),
      request_id: test_request_id(),
      timestamp: test_timestamp(),
      client_info: context.ClientInfo(
        session_token: option.None,
        ip: option.Some("127.0.0.1"),
        user_agent: option.Some("gleeunit"),
        referrer: option.None,
      ),
    )
  let request =
    login_dto.LoginRequest(email: test_email_address(), token: "login-token")

  let #(run_result, updated_db) =
    run_test_program(login_domain.login(ctx, request), ctx, db)

  assert run_result
    == Ok(login_domain.LoginResult(
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
}

pub fn send_login_token_for_suspended_user_returns_account_state_error_test() {
  let fixture =
    suspended_integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request = login_token_dto.LoginTokenRequest(email: fixture.user.email)

  let #(run_result, db) =
    run_test_program(
      send_login_token_domain.send_login_token(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
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

pub fn login_for_suspended_user_returns_account_state_error_test() {
  let login_token =
    login_token_model.LoginToken(
      id: must_uuid("00000000-0000-0000-0000-000000000601"),
      email: test_email_address(),
      token: "login-token",
      created_at: test_timestamp(),
      used_at: option.None,
    )
  let fixture =
    suspended_integration_fixture(
      next_uuids: [
        must_uuid("00000000-0000-0000-0000-000000000602"),
        must_uuid("00000000-0000-0000-0000-000000000603"),
        must_uuid("00000000-0000-0000-0000-000000000604"),
      ],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let db =
    TestDb(
      ..fixture.db,
      login_tokens: dict.from_list([#(uuid_key(login_token.id), login_token)]),
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
    login_dto.LoginRequest(email: test_email_address(), token: "login-token")

  let #(run_result, updated_db) =
    run_test_program(login_domain.login(ctx, request), ctx, db)

  assert run_result
    == Error(
      error.policy(policy_error.ForbiddenAccountState(
        action: api_action.public(public_action.LoginAction),
        account_state: account_model.Suspended,
      )),
    )
  assert updated_db.write_steps == []
}

pub fn snippet_spam_filter_allows_normal_code_test() {
  assert snippet_spam.ensure_clean(
      snippet_dto.SnippetData(
        title: "Hello world",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [
          snippet_model.File(name: "main.py", content: "print(\"hello\")"),
        ],
      ),
    )
    == Ok(Nil)
}

pub fn snippet_spam_filter_blocks_obvious_spam_test() {
  let result =
    snippet_spam.ensure_clean(
      snippet_dto.SnippetData(
        title: "Earn money fast",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [
          snippet_model.File(
            name: "promo.txt",
            content: "Contact me on Telegram https://t.me/spam_now click here",
          ),
        ],
      ),
    )

  let assert Error(validation_error.SpamDetected(message)) = result
  assert message != ""
}

pub fn create_snippet_rejects_empty_files_test() {
  let fixture =
    integration_fixture(
      next_uuids: [must_uuid("00000000-0000-0000-0000-000000000701")],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request =
    snippet_dto.CreateSnippetRequest(
      data: snippet_dto.SnippetData(
        title: "Snippet",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [],
      ),
    )

  let #(run_result, db) =
    run_test_program(
      create_snippet_domain.create_snippet(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Error(error.validation(validation_error.FilesMissing))
  assert db.write_steps == []
}

pub fn create_snippet_rejects_too_long_title_test() {
  let fixture =
    integration_fixture(
      next_uuids: [must_uuid("00000000-0000-0000-0000-000000000702")],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request =
    snippet_dto.CreateSnippetRequest(
      data: snippet_dto.SnippetData(
        title: repeat_string("a", 201),
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [snippet_model.File(name: "main.py", content: "print(1)")],
      ),
    )

  let #(run_result, db) =
    run_test_program(
      create_snippet_domain.create_snippet(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Error(error.validation(validation_error.FieldTooLong("title", 200)))
  assert db.write_steps == []
}

pub fn update_snippet_rejects_too_long_file_content_test() {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let request =
    snippet_dto.UpdateSnippetRequest(
      slug: fixture.snippet.slug,
      data: snippet_dto.SnippetData(
        title: "Snippet",
        language: language.Python,
        visibility: snippet_model.Public,
        stdin: "",
        run_instructions: option.None,
        files: [
          snippet_model.File(
            name: "main.py",
            content: repeat_string("a", 100_001),
          ),
        ],
      ),
    )

  let #(run_result, db) =
    run_test_program(
      update_snippet_domain.update_snippet(fixture.ctx, request),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Error(
      error.validation(validation_error.FieldTooLong(
        "files[0].content",
        100_000,
      )),
    )
  assert db.write_steps == []
}

pub fn schedule_delete_account_sets_delete_job_id_test() {
  let delete_job_id = must_uuid("00000000-0000-0000-0000-000000000102")
  let base_fixture =
    integration_fixture(
      next_uuids: [
        must_uuid("00000000-0000-0000-0000-000000000101"),
        delete_job_id,
      ],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let delete_account_policy =
    job_model.JobTypePolicy(
      ..test_job_type_policy(job_model.DeleteAccountJob),
      max_attempts: 9,
      timeout_seconds: 777,
    )
  let fixture =
    TestFixture(
      ..base_fixture,
      db: TestDb(
        ..base_fixture.db,
        job_type_policies: dict.insert(
          base_fixture.db.job_type_policies,
          job_model.job_type_to_string(job_model.DeleteAccountJob),
          delete_account_policy,
        ),
      ),
    )

  let #(run_result, db) =
    run_test_program(
      schedule_delete_account_domain.schedule_delete_account(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Ok(Nil)

  let assert Ok(updated_account) =
    dict.get(db.accounts, uuid_key(fixture.account.id))
  let assert option.Some(stored_job_id) = updated_account.delete_job_id
  let assert Ok(created_job) = dict.get(db.jobs, uuid_key(stored_job_id))

  assert stored_job_id == delete_job_id
  assert created_job.job_type == job_model.DeleteAccountJob
  assert created_job.max_attempts == 9
  assert created_job.timeout_seconds == 777
}

pub fn schedule_delete_account_rejects_existing_pending_delete_job_test() {
  let delete_job =
    job_model.delete_account_job(
      must_uuid("00000000-0000-0000-0000-000000000202"),
      option.Some(test_request_id()),
      test_timestamp(),
      test_timestamp(),
      test_account_id(),
      test_email_address(),
      test_job_type_policy(job_model.DeleteAccountJob),
    )
  let fixture =
    integration_fixture(
      next_uuids: [
        must_uuid("00000000-0000-0000-0000-000000000201"),
        must_uuid("00000000-0000-0000-0000-000000000299"),
      ],
      jobs: [delete_job],
      account_delete_job_id: option.Some(delete_job.id),
    )

  let #(run_result, db) =
    run_test_program(
      schedule_delete_account_domain.schedule_delete_account(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result
    == Error(error.resource(resource_error.AccountDeleteAlreadyScheduled))

  let assert Ok(updated_account) =
    dict.get(db.accounts, uuid_key(fixture.account.id))

  assert updated_account.delete_job_id == option.Some(delete_job.id)
  assert list.length(dict.to_list(db.jobs)) == 1
  assert dict.get(db.jobs, uuid_key(delete_job.id)) == Ok(delete_job)
}

pub fn cancel_delete_account_clears_delete_job_id_and_removes_job_test() {
  let delete_job =
    job_model.delete_account_job(
      must_uuid("00000000-0000-0000-0000-000000000302"),
      option.Some(test_request_id()),
      test_timestamp(),
      test_timestamp(),
      test_account_id(),
      test_email_address(),
      test_job_type_policy(job_model.DeleteAccountJob),
    )
  let fixture =
    integration_fixture(
      next_uuids: [must_uuid("00000000-0000-0000-0000-000000000301")],
      jobs: [delete_job],
      account_delete_job_id: option.Some(delete_job.id),
    )

  let #(run_result, db) =
    run_test_program(
      cancel_delete_account_domain.cancel_delete_account(fixture.ctx),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Ok(Nil)

  let assert Ok(updated_account) =
    dict.get(db.accounts, uuid_key(fixture.account.id))

  assert updated_account.delete_job_id == option.None
  assert dict.get(db.jobs, uuid_key(delete_job.id)) == Error(Nil)
}

pub fn delete_account_job_execution_removes_data_in_order_test() {
  let send_email_policy =
    job_model.JobTypePolicy(
      ..test_job_type_policy(job_model.SendEmailJob),
      max_attempts: 3,
      timeout_seconds: 900,
    )
  let scheduled_job =
    job_model.delete_account_job(
      must_uuid("00000000-0000-0000-0000-000000000402"),
      option.Some(test_request_id()),
      test_timestamp(),
      test_timestamp(),
      test_account_id(),
      test_email_address(),
      test_job_type_policy(job_model.DeleteAccountJob),
    )
  let running_job = job_model.start(scheduled_job, test_timestamp())
  let base_fixture =
    integration_fixture(
      next_uuids: [must_uuid("00000000-0000-0000-0000-000000000403")],
      jobs: [running_job],
      account_delete_job_id: option.Some(running_job.id),
    )
  let fixture =
    TestFixture(
      ..base_fixture,
      db: TestDb(
        ..base_fixture.db,
        job_type_policies: dict.insert(
          base_fixture.db.job_type_policies,
          job_model.job_type_to_string(job_model.SendEmailJob),
          send_email_policy,
        ),
      ),
    )

  let #(run_result, db) =
    run_test_program(
      job_manager_domain.process_job(fixture.ctx, running_job),
      fixture.ctx,
      fixture.db,
    )

  assert run_result == Ok(Nil)

  let assert Ok(completed_job) = dict.get(db.jobs, uuid_key(running_job.id))
  let assert Ok(created_email_job) =
    dict.get(
      db.jobs,
      uuid_key(must_uuid("00000000-0000-0000-0000-000000000403")),
    )

  assert dict.to_list(db.accounts) == []
  assert dict.to_list(db.users) == []
  assert dict.to_list(db.sessions) == []
  assert dict.to_list(db.snippets) == []
  assert completed_job.status == job_model.Done
  assert completed_job.completed_at == option.Some(test_system_time())
  assert created_email_job.job_type == job_model.SendEmailJob
  assert created_email_job.status == job_model.Pending
  assert created_email_job.max_attempts == 3
  assert created_email_job.timeout_seconds == 900
  assert list.reverse(db.deletion_steps)
    == [
      "delete_sessions_by_account_id",
      "delete_snippets_by_account_id",
      "delete_users_by_account_id",
      "delete_account",
    ]
}

pub fn recover_next_expired_job_reschedules_running_job_test() {
  let scheduled_job =
    job_model.delete_account_job(
      must_uuid("00000000-0000-0000-0000-000000000411"),
      option.Some(test_request_id()),
      test_timestamp(),
      test_timestamp(),
      test_account_id(),
      test_email_address(),
      test_job_type_policy(job_model.DeleteAccountJob),
    )
  let expired_job =
    job_model.start(
      scheduled_job,
      timestamp.from_unix_seconds_and_nanoseconds(1_699_999_000, 0),
    )
  let ctx =
    context.Context(
      ..test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [expired_job],
      account_delete_job_id: option.Some(expired_job.id),
    )

  let #(run_result, db) =
    run_test_program(
      job_manager_domain.recover_next_expired_job(ctx),
      ctx,
      fixture.db,
    )

  let assert Ok(option.Some(recovered_job)) = run_result
  let assert Ok(stored_job) = dict.get(db.jobs, uuid_key(expired_job.id))

  assert recovered_job.status == job_model.Pending
  assert recovered_job.started_at == option.None
  assert recovered_job.lease_expires_at == option.None
  assert recovered_job.timed_out_at == option.Some(ctx.timestamp)
  assert recovered_job.last_error == option.Some("timeout_exceeded")
  assert stored_job == recovered_job
}

pub fn enqueue_next_due_periodic_job_creates_job_and_advances_schedule_test() {
  let periodic_job_id = must_uuid("00000000-0000-0000-0000-000000000801")
  let enqueued_job_id = must_uuid("00000000-0000-0000-0000-000000000802")
  let periodic_job =
    periodic_job_model.PeriodicJob(
      id: periodic_job_id,
      job_type: job_model.CleanApiLogJob,
      payload: option.None,
      interval_seconds: 86_400,
      enabled: True,
      next_run_at: test_timestamp(),
      last_enqueued_at: option.None,
      last_enqueue_error: option.None,
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let ctx = context.Context(..test_context(), timestamp: test_timestamp())
  let clean_api_log_policy =
    job_model.JobTypePolicy(
      ..test_job_type_policy(job_model.CleanApiLogJob),
      max_attempts: 2,
      timeout_seconds: 1800,
    )
  let db =
    TestDb(
      ..empty_test_db(),
      job_type_policies: dict.insert(
        empty_test_db().job_type_policies,
        job_model.job_type_to_string(job_model.CleanApiLogJob),
        clean_api_log_policy,
      ),
      periodic_jobs: dict.from_list([#(uuid_key(periodic_job_id), periodic_job)]),
      next_uuids: [enqueued_job_id],
    )

  let #(run_result, updated_db) =
    run_test_program(
      periodic_job_manager_domain.enqueue_next_due_periodic_job(ctx),
      ctx,
      db,
    )

  assert run_result == Ok(True)
  let assert Ok(enqueued_job) =
    dict.get(updated_db.jobs, uuid_key(enqueued_job_id))
  let assert Ok(updated_periodic_job) =
    dict.get(updated_db.periodic_jobs, uuid_key(periodic_job_id))

  assert enqueued_job.periodic_job_id == option.Some(periodic_job_id)
  assert enqueued_job.job_type == job_model.CleanApiLogJob
  assert enqueued_job.status == job_model.Pending
  assert enqueued_job.max_attempts == 2
  assert enqueued_job.timeout_seconds == 1800
  assert updated_periodic_job.last_enqueued_at == option.Some(test_timestamp())
  assert updated_periodic_job.last_enqueue_error == option.None
  assert updated_periodic_job.next_run_at
    == timestamp.from_unix_seconds_and_nanoseconds(1_700_086_400, 0)
}

pub fn enqueue_next_due_periodic_job_returns_false_when_no_jobs_are_due_test() {
  let periodic_job =
    periodic_job_model.PeriodicJob(
      id: must_uuid("00000000-0000-0000-0000-000000000901"),
      job_type: job_model.CleanApiLogJob,
      payload: option.None,
      interval_seconds: 86_400,
      enabled: True,
      next_run_at: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_060, 0),
      last_enqueued_at: option.None,
      last_enqueue_error: option.None,
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let ctx = context.Context(..test_context(), timestamp: test_timestamp())
  let db =
    TestDb(
      ..empty_test_db(),
      periodic_jobs: dict.from_list([#(uuid_key(periodic_job.id), periodic_job)]),
    )

  let #(run_result, updated_db) =
    run_test_program(
      periodic_job_manager_domain.enqueue_next_due_periodic_job(ctx),
      ctx,
      db,
    )

  assert run_result == Ok(False)
  assert dict.to_list(updated_db.jobs) == []
  assert dict.get(updated_db.periodic_jobs, uuid_key(periodic_job.id))
    == Ok(periodic_job)
}

pub fn clean_jobs_deletes_only_done_jobs_before_cutoff_test() {
  let old_done_job =
    job_model.Job(
      id: must_uuid("00000000-0000-0000-0000-000000000a01"),
      request_id: option.None,
      periodic_job_id: option.None,
      job_type: job_model.CleanApiLogJob,
      payload: option.None,
      status: job_model.Done,
      attempts: 1,
      max_attempts: 5,
      timeout_seconds: 120,
      base_backoff_seconds: 5,
      max_backoff_seconds: 300,
      run_at: timestamp.from_unix_seconds_and_nanoseconds(1_650_000_000, 0),
      started_at: option.Some(timestamp.from_unix_seconds_and_nanoseconds(
        1_650_000_010,
        0,
      )),
      lease_expires_at: option.None,
      completed_at: option.Some(timestamp.from_unix_seconds_and_nanoseconds(
        1_697_300_000,
        0,
      )),
      timed_out_at: option.None,
      last_error: option.None,
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_650_000_000, 0),
      updated_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
    )
  let old_failed_job =
    job_model.Job(
      ..old_done_job,
      id: must_uuid("00000000-0000-0000-0000-000000000a02"),
      status: job_model.Failed,
    )
  let recent_done_job =
    job_model.Job(
      ..old_done_job,
      id: must_uuid("00000000-0000-0000-0000-000000000a03"),
      completed_at: option.Some(timestamp.from_unix_seconds_and_nanoseconds(
        1_699_900_000,
        0,
      )),
      updated_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0),
    )
  let ctx =
    context.Context(
      ..test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    TestDb(
      ..empty_test_db(),
      jobs: dict.from_list([
        #(uuid_key(old_done_job.id), old_done_job),
        #(uuid_key(old_failed_job.id), old_failed_job),
        #(uuid_key(recent_done_job.id), recent_done_job),
      ]),
    )

  let #(run_result, updated_db) =
    run_test_program(clean_jobs_domain.clean_jobs(ctx), ctx, db)

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.jobs, uuid_key(old_done_job.id)) == Error(Nil)
  assert dict.get(updated_db.jobs, uuid_key(old_failed_job.id))
    == Ok(old_failed_job)
  assert dict.get(updated_db.jobs, uuid_key(recent_done_job.id))
    == Ok(recent_done_job)
}

pub fn clean_run_log_deletes_only_old_rows_test() {
  let old_run_log =
    run_log_model.RunLog(
      id: must_uuid("00000000-0000-0000-0000-000000000d01"),
      request_id: test_request_id(),
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
      session_id: option.None,
      user_id: option.None,
      language: language.Python,
      outcome: run_log_model.RunSucceeded,
      duration_ns: option.Some(1000),
      failure_message: option.None,
    )
  let recent_run_log =
    run_log_model.RunLog(
      ..old_run_log,
      id: must_uuid("00000000-0000-0000-0000-000000000d02"),
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0),
    )
  let ctx =
    context.Context(
      ..test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    TestDb(
      ..empty_test_db(),
      run_logs: dict.from_list([
        #(uuid_key(old_run_log.id), old_run_log),
        #(uuid_key(recent_run_log.id), recent_run_log),
      ]),
    )

  let #(run_result, updated_db) =
    run_test_program(clean_run_log_domain.clean_run_log(ctx), ctx, db)

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.run_logs, uuid_key(old_run_log.id)) == Error(Nil)
  assert dict.get(updated_db.run_logs, uuid_key(recent_run_log.id))
    == Ok(recent_run_log)
}

pub fn clean_user_actions_deletes_only_old_rows_test() {
  let old_action =
    user_action.UserAction(
      id: must_uuid("00000000-0000-0000-0000-000000000b01"),
      request_id: test_request_id(),
      action: api_action.public(public_action.LoginAction),
      ip: option.Some("127.0.0.1"),
      user_id: option.None,
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
    )
  let recent_action =
    user_action.UserAction(
      ..old_action,
      id: must_uuid("00000000-0000-0000-0000-000000000b02"),
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0),
    )
  let ctx =
    context.Context(
      ..test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    TestDb(
      ..empty_test_db(),
      user_actions: dict.from_list([
        #(uuid_key(old_action.id), old_action),
        #(uuid_key(recent_action.id), recent_action),
      ]),
    )

  let #(run_result, updated_db) =
    run_test_program(clean_user_actions_domain.clean_user_actions(ctx), ctx, db)

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.user_actions, uuid_key(old_action.id))
    == Error(Nil)
  assert dict.get(updated_db.user_actions, uuid_key(recent_action.id))
    == Ok(recent_action)
}

pub fn clean_login_tokens_deletes_only_old_rows_test() {
  let old_login_token =
    login_token_model.LoginToken(
      id: must_uuid("00000000-0000-0000-0000-000000000c01"),
      email: test_email_address(),
      token: "old-login-token",
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_697_300_000, 0),
      used_at: option.None,
    )
  let recent_login_token =
    login_token_model.LoginToken(
      ..old_login_token,
      id: must_uuid("00000000-0000-0000-0000-000000000c02"),
      token: "recent-login-token",
      created_at: timestamp.from_unix_seconds_and_nanoseconds(1_699_900_000, 0),
    )
  let ctx =
    context.Context(
      ..test_context(),
      timestamp: timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0),
    )
  let db =
    TestDb(
      ..empty_test_db(),
      login_tokens: dict.from_list([
        #(uuid_key(old_login_token.id), old_login_token),
        #(uuid_key(recent_login_token.id), recent_login_token),
      ]),
    )

  let #(run_result, updated_db) =
    run_test_program(clean_login_tokens_domain.clean_login_tokens(ctx), ctx, db)

  assert run_result == Ok(Nil)
  assert dict.get(updated_db.login_tokens, uuid_key(old_login_token.id))
    == Error(Nil)
  assert dict.get(updated_db.login_tokens, uuid_key(recent_login_token.id))
    == Ok(recent_login_token)
}

type TestFixture {
  TestFixture(
    ctx: context.Context,
    db: TestDb,
    account: account_model.Account,
    user: user_model.User,
    session: session_model.Session,
    snippet: snippet_model.Snippet,
  )
}

type TestDb {
  TestDb(
    dynamic_config: dynamic_config.DynamicConfig,
    accounts: Dict(String, account_model.Account),
    users: Dict(String, user_model.User),
    email_templates: Dict(String, email_template.EmailTemplate),
    login_tokens: Dict(String, login_token_model.LoginToken),
    sessions: Dict(String, session_model.Session),
    session_ids_by_token: Dict(String, String),
    run_logs: Dict(String, run_log_model.RunLog),
    jobs: Dict(String, job_model.Job),
    job_type_policies: Dict(String, job_model.JobTypePolicy),
    periodic_jobs: Dict(String, periodic_job_model.PeriodicJob),
    snippets: Dict(String, snippet_model.Snippet),
    user_actions: Dict(String, user_action.UserAction),
    user_action_count: Int,
    write_steps: List(String),
    deletion_steps: List(String),
    next_uuids: List(uuid.Uuid),
    system_time: timestamp.Timestamp,
  )
}

fn integration_fixture(
  next_uuids next_uuids: List(uuid.Uuid),
  jobs jobs: List(job_model.Job),
  account_delete_job_id account_delete_job_id: option.Option(uuid.Uuid),
) -> TestFixture {
  let account =
    account_model.Account(
      id: test_account_id(),
      account_state: account_model.Active,
      account_state_reason: option.None,
      account_tier: account_model.FreeTier,
      delete_job_id: account_delete_job_id,
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let user =
    user_model.User(
      id: test_user_id(),
      account_id: account.id,
      email: email_address_model.EmailAddress("user@example.com"),
      username: "user",
      role: user_model.RegularUser,
      last_login_at: test_timestamp(),
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let session =
    session_model.Session(
      id: test_session_id(),
      user_id: user.id,
      token: "session-token",
      previous_token: option.None,
      previous_token_valid_until: option.None,
      ip: option.Some("127.0.0.1"),
      user_agent: option.Some("gleeunit"),
      created_at: test_timestamp(),
      token_updated_at: test_timestamp(),
    )
  let snippet =
    snippet_model.Snippet(
      id: test_snippet_id(),
      slug: "snippet-slug",
      user_id: user.id,
      title: "Snippet",
      language: language.Python,
      visibility: snippet_model.Public,
      stdin: "",
      run_instructions: option.None,
      files: [snippet_model.File(name: "main.py", content: "print(1)")],
      created_at: test_timestamp(),
      updated_at: test_timestamp(),
    )
  let db =
    TestDb(
      dynamic_config: test_dynamic_config(),
      accounts: dict.from_list([#(uuid_key(account.id), account)]),
      users: dict.from_list([#(uuid_key(user.id), user)]),
      email_templates: default_email_templates(),
      login_tokens: dict.new(),
      sessions: dict.from_list([#(uuid_key(session.id), session)]),
      session_ids_by_token: dict.from_list([
        #(session.token, uuid_key(session.id)),
      ]),
      run_logs: dict.new(),
      jobs: dict.from_list(list.map(jobs, fn(job) { #(uuid_key(job.id), job) })),
      job_type_policies: default_job_type_policies(),
      periodic_jobs: dict.new(),
      snippets: dict.from_list([#(uuid_key(snippet.id), snippet)]),
      user_actions: dict.new(),
      user_action_count: 0,
      write_steps: [],
      deletion_steps: [],
      next_uuids: next_uuids,
      system_time: test_system_time(),
    )
  let ctx =
    context.Context(
      ..test_context(),
      request_id: test_request_id(),
      timestamp: test_timestamp(),
      client_info: context.ClientInfo(
        session_token: option.Some(session.token),
        ip: option.Some("127.0.0.1"),
        user_agent: option.Some("gleeunit"),
        referrer: option.None,
      ),
    )

  TestFixture(
    ctx: ctx,
    db: db,
    account: account,
    user: user,
    session: session,
    snippet: snippet,
  )
}

fn suspended_integration_fixture(
  next_uuids next_uuids: List(uuid.Uuid),
  jobs jobs: List(job_model.Job),
  account_delete_job_id account_delete_job_id: option.Option(uuid.Uuid),
) -> TestFixture {
  let fixture =
    integration_fixture(
      next_uuids: next_uuids,
      jobs: jobs,
      account_delete_job_id: account_delete_job_id,
    )
  let suspended_account =
    account_model.Account(
      ..fixture.account,
      account_state: account_model.Suspended,
      account_state_reason: option.Some("suspended for test"),
    )
  let db =
    TestDb(
      ..fixture.db,
      accounts: dict.insert(
        fixture.db.accounts,
        uuid_key(suspended_account.id),
        suspended_account,
      ),
    )

  TestFixture(..fixture, db: db, account: suspended_account)
}

fn admin_integration_fixture() -> TestFixture {
  let fixture =
    integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let admin_user = user_model.User(..fixture.user, role: user_model.AdminUser)
  let db =
    TestDb(
      ..fixture.db,
      users: dict.from_list([#(uuid_key(admin_user.id), admin_user)]),
    )

  TestFixture(..fixture, db: db, user: admin_user)
}

fn empty_test_db() -> TestDb {
  TestDb(
    dynamic_config: test_dynamic_config(),
    accounts: dict.new(),
    users: dict.new(),
    email_templates: default_email_templates(),
    login_tokens: dict.new(),
    sessions: dict.new(),
    session_ids_by_token: dict.new(),
    run_logs: dict.new(),
    jobs: dict.new(),
    job_type_policies: default_job_type_policies(),
    periodic_jobs: dict.new(),
    snippets: dict.new(),
    user_actions: dict.new(),
    user_action_count: 0,
    write_steps: [],
    deletion_steps: [],
    next_uuids: [],
    system_time: test_system_time(),
  )
}

fn default_email_templates() -> Dict(String, email_template.EmailTemplate) {
  dict.from_list([
    #(
      email_template.to_db_name(email_template.LoginTokenTemplate),
      email_template.EmailTemplate(
        name: email_template.LoginTokenTemplate,
        subject_template: "Your login token",
        text_body_template: "Your login token is: {{token}}",
        html_body_template: option.None,
        updated_at: test_system_time(),
      ),
    ),
    #(
      email_template.to_db_name(email_template.AccountDeletedTemplate),
      email_template.EmailTemplate(
        name: email_template.AccountDeletedTemplate,
        subject_template: "Your account has been deleted",
        text_body_template: "Your account has been deleted.",
        html_body_template: option.None,
        updated_at: test_system_time(),
      ),
    ),
  ])
}

fn default_job_type_policies() -> Dict(String, job_model.JobTypePolicy) {
  let created_at = test_system_time()

  [
    job_model.SendEmailJob,
    job_model.DeleteAccountJob,
    job_model.CleanApiLogJob,
    job_model.CleanPageLogJob,
    job_model.CleanPageviewLogJob,
    job_model.CleanRunLogJob,
    job_model.CleanJobLogJob,
    job_model.CleanJobsJob,
    job_model.CleanLoginTokensJob,
    job_model.CleanUserActionsJob,
    job_model.AggregateMetricsJob,
  ]
  |> list.map(fn(job_type) {
    let policy =
      job_model.JobTypePolicy(
        job_type: job_type,
        max_attempts: 5,
        timeout_seconds: 120,
        base_backoff_seconds: 5,
        max_backoff_seconds: 300,
        created_at: created_at,
        updated_at: created_at,
      )
    #(job_model.job_type_to_string(job_type), policy)
  })
  |> dict.from_list
}

fn test_job_type_policy(
  job_type: job_model.JobType,
) -> job_model.JobTypePolicy {
  let assert Ok(policy) =
    dict.get(
      default_job_type_policies(),
      job_model.job_type_to_string(job_type),
    )
  policy
}

fn repeat_string(value: String, count: Int) -> String {
  case count <= 0 {
    True -> ""
    False -> value <> repeat_string(value, count - 1)
  }
}

fn run_test_program(
  effect: program_types.Program(a),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    program_types.Pure(value) -> #(Ok(value), db)
    program_types.Fail(err) -> #(Error(err), db)
    program_types.Attempt(program:, on_error:) ->
      case run_test_program(program, ctx, db) {
        #(Ok(value), next_db) -> #(Ok(value), next_db)
        #(Error(err), next_db) -> run_test_program(on_error(err), ctx, next_db)
      }
    program_types.Impure(next_effect) ->
      case next_effect {
        program_types.BasicEffect(basic_effect) ->
          run_test_basic_effect(basic_effect, ctx, db)
        program_types.EmailEffect(email_effect) ->
          run_test_email_effect(email_effect, ctx, db)
        program_types.DockerRunEffect(docker_run_effect) ->
          run_test_docker_run_effect(docker_run_effect, db)
        program_types.GetLanguageVersionEffect(get_language_version_effect) ->
          run_test_get_language_version_effect(get_language_version_effect, db)
        program_types.AppConfigEffect(app_config_effect) ->
          run_test_app_config_effect(app_config_effect, ctx, db)
        program_types.DbEffect(db_effect) ->
          run_test_db_effect(db_effect, ctx, db)
        program_types.TransactionEffect(transaction_effect) ->
          case transaction_effect {
            program_types.Run(program: tx_program) ->
              case run_test_tx_program(tx_program, ctx, db) {
                #(Ok(next_program), next_db) ->
                  run_test_program(next_program, ctx, next_db)
                #(Error(err), next_db) -> #(Error(err), next_db)
              }
          }
      }
  }
}

fn run_test_tx_program(
  effect: program_types.TransactionProgram(a),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    program_types.TxPure(value) -> #(Ok(value), db)
    program_types.TxFail(err) -> #(Error(err), db)
    program_types.TxImpure(db_effect) ->
      run_test_tx_db_effect(db_effect, ctx, db)
  }
}

fn run_test_basic_effect(
  effect: basic_algebra.BasicEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    basic_algebra.NewToken(_, _, next) ->
      run_test_program(next("random"), ctx, db)
    basic_algebra.SystemTime(next) ->
      run_test_program(next(db.system_time), ctx, db)
    basic_algebra.UuidV7(next) -> {
      let #(uuid_value, next_db) = pop_uuid(db)
      run_test_program(next(uuid_value), ctx, next_db)
    }
    basic_algebra.Log(_, _, next) -> run_test_program(next, ctx, db)
  }
}

fn run_test_email_effect(
  effect: email_algebra.EmailEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    email_algebra.SendEmail(_, next) ->
      run_test_program(
        next(
          Error(
            error.infra(
              infra_error.EmailError(infra_error.EmailDeliveryFailed(
                "test_delivery_failure",
              )),
            ),
          ),
        ),
        ctx,
        db,
      )
  }
}

fn run_test_docker_run_effect(
  effect: docker_run_algebra.DockerRunEffect(program_types.Program(a)),
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    docker_run_algebra.RunCode(_, _) -> #(
      Error(error.run_request_error(run_request_error.ServerRunRequestError)),
      db,
    )
  }
}

fn run_test_get_language_version_effect(
  effect: get_language_version_algebra.GetLanguageVersionEffect(
    program_types.Program(a),
  ),
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    get_language_version_algebra.GetLanguageVersion(_, _, _) -> #(
      Error(error.run_request_error(run_request_error.ServerRunRequestError)),
      db,
    )
  }
}

fn run_test_app_config_effect(
  effect: app_config_algebra.AppConfigEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    app_config_algebra.GetDynamicConfig(next:) ->
      run_test_program(next(Ok(db.dynamic_config)), ctx, db)
    app_config_algebra.UpsertDebugConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: config,
            availability: test_availability_config(),
            auth: dynamic_config.AuthConfig(
              login_token_max_age: 900,
              session_token_max_age: 86_400,
              session_cookie_max_age: 86_400,
              session_refresh_interval_seconds: 300,
              session_previous_token_grace_seconds: 60,
              session_heartbeat_interval_seconds: 60,
            ),
            cleanup: test_cleanup_config(),
            log_worker: test_log_worker_config(),
            language_version_cache_worker: test_language_version_cache_worker_config(),
            docker_run: option.None,
            cloudflare: option.None,
            email: option.None,
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
    app_config_algebra.UpsertAvailabilityConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: dynamic_config.DebugConfig(enabled: False),
            availability: config,
            auth: dynamic_config.AuthConfig(
              login_token_max_age: 900,
              session_token_max_age: 86_400,
              session_cookie_max_age: 86_400,
              session_refresh_interval_seconds: 300,
              session_previous_token_grace_seconds: 60,
              session_heartbeat_interval_seconds: 60,
            ),
            cleanup: test_cleanup_config(),
            log_worker: test_log_worker_config(),
            language_version_cache_worker: test_language_version_cache_worker_config(),
            docker_run: option.None,
            cloudflare: option.None,
            email: option.None,
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
    app_config_algebra.UpsertAuthConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: dynamic_config.DebugConfig(enabled: False),
            availability: test_availability_config(),
            auth: config,
            cleanup: test_cleanup_config(),
            log_worker: test_log_worker_config(),
            language_version_cache_worker: test_language_version_cache_worker_config(),
            docker_run: option.None,
            cloudflare: option.None,
            email: option.None,
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
    app_config_algebra.UpsertCleanupConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: dynamic_config.DebugConfig(enabled: False),
            availability: test_availability_config(),
            auth: dynamic_config.AuthConfig(
              login_token_max_age: 900,
              session_token_max_age: 86_400,
              session_cookie_max_age: 86_400,
              session_refresh_interval_seconds: 300,
              session_previous_token_grace_seconds: 60,
              session_heartbeat_interval_seconds: 60,
            ),
            cleanup: config,
            log_worker: test_log_worker_config(),
            language_version_cache_worker: test_language_version_cache_worker_config(),
            docker_run: option.None,
            cloudflare: option.None,
            email: option.None,
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
    app_config_algebra.UpsertLogWorkerConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: dynamic_config.DebugConfig(enabled: False),
            availability: test_availability_config(),
            auth: dynamic_config.AuthConfig(
              login_token_max_age: 900,
              session_token_max_age: 86_400,
              session_cookie_max_age: 86_400,
              session_refresh_interval_seconds: 300,
              session_previous_token_grace_seconds: 60,
              session_heartbeat_interval_seconds: 60,
            ),
            cleanup: test_cleanup_config(),
            log_worker: config,
            language_version_cache_worker: test_language_version_cache_worker_config(),
            docker_run: option.None,
            cloudflare: option.None,
            email: option.None,
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
    app_config_algebra.UpsertLanguageVersionCacheWorkerConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: dynamic_config.DebugConfig(enabled: False),
            availability: test_availability_config(),
            auth: dynamic_config.AuthConfig(
              login_token_max_age: 900,
              session_token_max_age: 86_400,
              session_cookie_max_age: 86_400,
              session_refresh_interval_seconds: 300,
              session_previous_token_grace_seconds: 60,
              session_heartbeat_interval_seconds: 60,
            ),
            cleanup: test_cleanup_config(),
            log_worker: test_log_worker_config(),
            language_version_cache_worker: config,
            docker_run: option.None,
            cloudflare: option.None,
            email: option.None,
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
    app_config_algebra.UpsertRateLimitPolicy(
      action: _,
      policy: _,
      updated_at: _,
      next: next,
    ) -> run_test_program(next(Ok(test_dynamic_config())), ctx, db)
    app_config_algebra.UpsertDockerRunConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: dynamic_config.DebugConfig(enabled: False),
            availability: test_availability_config(),
            auth: dynamic_config.AuthConfig(
              login_token_max_age: 900,
              session_token_max_age: 86_400,
              session_cookie_max_age: 86_400,
              session_refresh_interval_seconds: 300,
              session_previous_token_grace_seconds: 60,
              session_heartbeat_interval_seconds: 60,
            ),
            cleanup: test_cleanup_config(),
            log_worker: test_log_worker_config(),
            language_version_cache_worker: test_language_version_cache_worker_config(),
            docker_run: option.Some(config),
            cloudflare: option.None,
            email: option.None,
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
    app_config_algebra.UpsertCloudflareConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: dynamic_config.DebugConfig(enabled: False),
            availability: test_availability_config(),
            auth: dynamic_config.AuthConfig(
              login_token_max_age: 900,
              session_token_max_age: 86_400,
              session_cookie_max_age: 86_400,
              session_refresh_interval_seconds: 300,
              session_previous_token_grace_seconds: 60,
              session_heartbeat_interval_seconds: 60,
            ),
            cleanup: test_cleanup_config(),
            log_worker: test_log_worker_config(),
            language_version_cache_worker: test_language_version_cache_worker_config(),
            docker_run: option.None,
            cloudflare: option.Some(config),
            email: option.None,
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
    app_config_algebra.UpsertEmailConfig(
      config: config,
      updated_at: _,
      next: next,
    ) ->
      run_test_program(
        next(
          Ok(dynamic_config.DynamicConfig(
            debug: dynamic_config.DebugConfig(enabled: False),
            availability: test_availability_config(),
            auth: dynamic_config.AuthConfig(
              login_token_max_age: 900,
              session_token_max_age: 86_400,
              session_cookie_max_age: 86_400,
              session_refresh_interval_seconds: 300,
              session_previous_token_grace_seconds: 60,
              session_heartbeat_interval_seconds: 60,
            ),
            cleanup: test_cleanup_config(),
            log_worker: test_log_worker_config(),
            language_version_cache_worker: test_language_version_cache_worker_config(),
            docker_run: option.None,
            cloudflare: option.None,
            email: option.Some(config),
            rate_limit_policies: dict.new(),
          )),
        ),
        ctx,
        db,
      )
  }
}

fn test_dynamic_config() -> dynamic_config.DynamicConfig {
  dynamic_config.DynamicConfig(
    debug: dynamic_config.DebugConfig(enabled: False),
    availability: test_availability_config(),
    auth: test_auth_config(),
    cleanup: test_cleanup_config(),
    log_worker: test_log_worker_config(),
    language_version_cache_worker: test_language_version_cache_worker_config(),
    docker_run: option.None,
    cloudflare: option.Some(test_cloudflare_config()),
    email: option.Some(test_email_config()),
    rate_limit_policies: dict.new(),
  )
}

fn test_cloudflare_config() -> dynamic_config.CloudflareConfig {
  dynamic_config.CloudflareConfig(
    account_id: "cf-account-id",
    api_token: "cf-api-token",
  )
}

fn test_email_config() -> dynamic_config.EmailConfig {
  dynamic_config.EmailConfig(
    from_address: "sender@example.com",
    from_name: option.Some("Sender"),
  )
}

fn test_log_worker_config() -> dynamic_config.LogWorkerConfig {
  dynamic_config.LogWorkerConfig(
    flush_interval_ms: 5000,
    max_batch_size: 100,
    max_buffer_size: 1000,
  )
}

fn test_language_version_cache_worker_config() -> dynamic_config.LanguageVersionCacheWorkerConfig {
  dynamic_config.LanguageVersionCacheWorkerConfig(
    refresh_interval_ms: 3_600_000,
    refresh_step_delay_ms: 1000,
    refresh_step_jitter_ms: 500,
    default_timeout_ms: 60_000,
  )
}

fn test_auth_config() -> dynamic_config.AuthConfig {
  dynamic_config.AuthConfig(
    login_token_max_age: 900,
    session_token_max_age: 86_400,
    session_cookie_max_age: 86_400,
    session_refresh_interval_seconds: 300,
    session_previous_token_grace_seconds: 60,
    session_heartbeat_interval_seconds: 60,
  )
}

fn test_availability_config() -> dynamic_config.AvailabilityConfig {
  dynamic_config.AvailabilityConfig(
    mode: availability_mode.NormalMode,
    message: "glot.io is temporarily unavailable right now.",
    retry_after_seconds: option.None,
  )
}

fn test_cleanup_config() -> dynamic_config.CleanupConfig {
  dynamic_config.CleanupConfig(
    api_log_retention_days: 30,
    page_log_retention_days: 30,
    pageview_log_retention_days: 30,
    run_log_retention_days: 30,
    job_log_retention_days: 30,
    jobs_retention_days: 30,
    login_tokens_retention_days: 30,
    user_actions_retention_days: 30,
  )
}

fn run_test_db_effect(
  effect: program_types.DbEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    program_types.AdminLogEffect(admin_log_effect) ->
      run_test_admin_log_effect(admin_log_effect, ctx, db)
    program_types.AnalyticsEffect(analytics_effect) ->
      run_test_analytics_effect(analytics_effect, ctx, db)
    program_types.ApiLogEffect(api_log_effect) ->
      run_test_api_log_effect(api_log_effect, ctx, db)
    program_types.AuthEffect(auth_effect) ->
      run_test_auth_effect(auth_effect, ctx, db)
    program_types.EmailTemplateEffect(email_template_effect) ->
      run_test_email_template_effect(email_template_effect, ctx, db)
    program_types.JobEffect(job_effect) ->
      run_test_job_effect(job_effect, ctx, db)
    program_types.JobLogEffect(job_log_effect) ->
      run_test_job_log_effect(job_log_effect, ctx, db)
    program_types.JobTypePolicyEffect(job_type_policy_effect) ->
      run_test_job_type_policy_effect(job_type_policy_effect, ctx, db)
    program_types.PageLogEffect(page_log_effect) ->
      run_test_page_log_effect(page_log_effect, ctx, db)
    program_types.PageviewLogEffect(pageview_log_effect) ->
      run_test_pageview_log_effect(pageview_log_effect, ctx, db)
    program_types.PeriodicJobEffect(periodic_job_effect) ->
      run_test_periodic_job_effect(periodic_job_effect, ctx, db)
    program_types.RunLogEffect(run_log_effect) ->
      run_test_run_log_effect(run_log_effect, ctx, db)
    program_types.SnippetEffect(snippet_effect) ->
      run_test_snippet_effect(snippet_effect, ctx, db)
    program_types.UserActionEffect(user_action_effect) ->
      run_test_user_action_effect(user_action_effect, ctx, db)
  }
}

fn run_test_tx_db_effect(
  effect: program_types.DbEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    program_types.AdminLogEffect(admin_log_effect) ->
      run_test_admin_log_tx_effect(admin_log_effect, ctx, db)
    program_types.AnalyticsEffect(analytics_effect) ->
      run_test_analytics_tx_effect(analytics_effect, ctx, db)
    program_types.ApiLogEffect(api_log_effect) ->
      run_test_api_log_tx_effect(api_log_effect, ctx, db)
    program_types.AuthEffect(auth_effect) ->
      run_test_auth_tx_effect(auth_effect, ctx, db)
    program_types.EmailTemplateEffect(email_template_effect) ->
      run_test_email_template_tx_effect(email_template_effect, ctx, db)
    program_types.JobEffect(job_effect) ->
      run_test_job_tx_effect(job_effect, ctx, db)
    program_types.JobLogEffect(job_log_effect) ->
      run_test_job_log_tx_effect(job_log_effect, ctx, db)
    program_types.JobTypePolicyEffect(job_type_policy_effect) ->
      run_test_job_type_policy_tx_effect(job_type_policy_effect, ctx, db)
    program_types.PageLogEffect(page_log_effect) ->
      run_test_page_log_tx_effect(page_log_effect, ctx, db)
    program_types.PageviewLogEffect(pageview_log_effect) ->
      run_test_pageview_log_tx_effect(pageview_log_effect, ctx, db)
    program_types.PeriodicJobEffect(periodic_job_effect) ->
      run_test_periodic_job_tx_effect(periodic_job_effect, ctx, db)
    program_types.RunLogEffect(run_log_effect) ->
      run_test_run_log_tx_effect(run_log_effect, ctx, db)
    program_types.SnippetEffect(snippet_effect) ->
      run_test_snippet_tx_effect(snippet_effect, ctx, db)
    program_types.UserActionEffect(user_action_effect) ->
      run_test_user_action_tx_effect(user_action_effect, ctx, db)
  }
}

fn run_test_api_log_effect(
  effect: api_log_algebra.ApiLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    api_log_algebra.DeleteApiLogBefore(before: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_admin_log_effect(
  effect: admin_log_algebra.AdminLogEffect(program_types.Program(a)),
  _ctx: context.Context,
  _db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    admin_log_algebra.ListApiLogs(_, _) ->
      panic as "Admin log list API effects are not used in backend tests"
    admin_log_algebra.GetApiLog(_, _) ->
      panic as "Admin log API detail effects are not used in backend tests"
    admin_log_algebra.ListRunLogs(_, _) ->
      panic as "Admin log list run effects are not used in backend tests"
    admin_log_algebra.GetRunLog(_, _) ->
      panic as "Admin log run detail effects are not used in backend tests"
    admin_log_algebra.ListJobLogs(_, _) ->
      panic as "Admin log list job effects are not used in backend tests"
    admin_log_algebra.GetJobLog(_, _) ->
      panic as "Admin log job detail effects are not used in backend tests"
  }
}

fn run_test_admin_log_tx_effect(
  effect: admin_log_algebra.AdminLogEffect(program_types.TransactionProgram(a)),
  _ctx: context.Context,
  _db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    admin_log_algebra.ListApiLogs(_, _) ->
      panic as "Admin log list API tx effects are not used in backend tests"
    admin_log_algebra.GetApiLog(_, _) ->
      panic as "Admin log API detail tx effects are not used in backend tests"
    admin_log_algebra.ListRunLogs(_, _) ->
      panic as "Admin log list run tx effects are not used in backend tests"
    admin_log_algebra.GetRunLog(_, _) ->
      panic as "Admin log run detail tx effects are not used in backend tests"
    admin_log_algebra.ListJobLogs(_, _) ->
      panic as "Admin log list job tx effects are not used in backend tests"
    admin_log_algebra.GetJobLog(_, _) ->
      panic as "Admin log job detail tx effects are not used in backend tests"
  }
}

fn run_test_analytics_effect(
  effect: analytics_algebra.AnalyticsEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    analytics_algebra.GetMaxCompletedMetricsDay(next:) ->
      run_test_program(next(Ok(option.None)), ctx, db)
    analytics_algebra.GetFirstMetricsSourceDay(before: _, next: next) ->
      run_test_program(next(Ok(option.None)), ctx, db)
    analytics_algebra.InsertMetricsPageviewDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsProductEventDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsRunDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsReliabilityPageDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsReliabilityApiDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsCompletedDay(day: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_analytics_tx_effect(
  effect: analytics_algebra.AnalyticsEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    analytics_algebra.GetMaxCompletedMetricsDay(next:) ->
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    analytics_algebra.GetFirstMetricsSourceDay(before: _, next: next) ->
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    analytics_algebra.InsertMetricsPageviewDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsProductEventDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsRunDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsReliabilityPageDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsReliabilityApiDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    analytics_algebra.InsertMetricsCompletedDay(day: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_api_log_tx_effect(
  effect: api_log_algebra.ApiLogEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    api_log_algebra.DeleteApiLogBefore(before: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_page_log_effect(
  effect: page_log_algebra.PageLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    page_log_algebra.DeletePageLogBefore(before: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_job_type_policy_effect(
  effect: job_type_policy_algebra.JobTypePolicyEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_type_policy_algebra.ListJobTypePolicies(next:) ->
      run_test_program(next(list_job_type_policies(db)), ctx, db)
    job_type_policy_algebra.GetJobTypePolicyByJobType(job_type:, next:) ->
      run_test_program(next(find_job_type_policy(db, job_type)), ctx, db)
    job_type_policy_algebra.UpsertJobTypePolicy(policy:, next:, ..) -> {
      let next_db = upsert_test_job_type_policy(db, policy)
      run_test_program(next(Nil), ctx, next_db)
    }
  }
}

fn run_test_job_type_policy_tx_effect(
  effect: job_type_policy_algebra.JobTypePolicyEffect(
    program_types.TransactionProgram(a),
  ),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_type_policy_algebra.ListJobTypePolicies(next:) ->
      run_test_tx_program(next(list_job_type_policies(db)), ctx, db)
    job_type_policy_algebra.GetJobTypePolicyByJobType(job_type:, next:) ->
      run_test_tx_program(next(find_job_type_policy(db, job_type)), ctx, db)
    job_type_policy_algebra.UpsertJobTypePolicy(policy:, next:, ..) -> {
      let next_db = upsert_test_job_type_policy(db, policy)
      run_test_tx_program(next(Nil), ctx, next_db)
    }
  }
}

fn run_test_page_log_tx_effect(
  effect: page_log_algebra.PageLogEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    page_log_algebra.DeletePageLogBefore(before: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_pageview_log_effect(
  effect: pageview_log_algebra.PageviewLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    pageview_log_algebra.DeletePageviewLogBefore(before: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_pageview_log_tx_effect(
  effect: pageview_log_algebra.PageviewLogEffect(
    program_types.TransactionProgram(a),
  ),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    pageview_log_algebra.DeletePageviewLogBefore(before: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_periodic_job_effect(
  effect: periodic_job_algebra.PeriodicJobEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    periodic_job_algebra.ListPeriodicJobs(next:) ->
      run_test_program(next(list_periodic_jobs(db)), ctx, db)
    periodic_job_algebra.GetNextPeriodicJob(now:, next:) ->
      run_test_program(next(find_next_periodic_job(db, now)), ctx, db)
    periodic_job_algebra.GetPeriodicJobById(id:, next:) ->
      run_test_program(next(find_periodic_job_by_id(db, id)), ctx, db)
    periodic_job_algebra.CreatePeriodicJob(periodic_job, next) ->
      run_test_program(next(Ok(Nil)), ctx, put_periodic_job(db, periodic_job))
    periodic_job_algebra.UpdatePeriodicJob(periodic_job, next) ->
      run_test_program(next(Ok(Nil)), ctx, put_periodic_job(db, periodic_job))
  }
}

fn run_test_periodic_job_tx_effect(
  effect: periodic_job_algebra.PeriodicJobEffect(
    program_types.TransactionProgram(a),
  ),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    periodic_job_algebra.ListPeriodicJobs(next:) ->
      run_test_tx_program(next(list_periodic_jobs(db)), ctx, db)
    periodic_job_algebra.GetNextPeriodicJob(now:, next:) ->
      run_test_tx_program(next(find_next_periodic_job(db, now)), ctx, db)
    periodic_job_algebra.GetPeriodicJobById(id:, next:) ->
      run_test_tx_program(next(find_periodic_job_by_id(db, id)), ctx, db)
    periodic_job_algebra.CreatePeriodicJob(periodic_job, next) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        put_periodic_job(db, periodic_job),
      )
    periodic_job_algebra.UpdatePeriodicJob(periodic_job, next) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        put_periodic_job(db, periodic_job),
      )
  }
}

fn run_test_run_log_effect(
  effect: run_log_algebra.RunLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    run_log_algebra.CreateRunLog(run_log: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
    run_log_algebra.DeleteRunLogBefore(before:, next:) ->
      run_test_program(next(Ok(Nil)), ctx, delete_run_logs_before(db, before))
  }
}

fn run_test_run_log_tx_effect(
  effect: run_log_algebra.RunLogEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    run_log_algebra.CreateRunLog(run_log: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
    run_log_algebra.DeleteRunLogBefore(before:, next:) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_run_logs_before(db, before),
      )
  }
}

fn run_test_auth_effect(
  effect: auth_algebra.AuthEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    auth_algebra.GetUserByEmail(email:, next:) ->
      run_test_program(next(find_user_by_email(db, email)), ctx, db)
    auth_algebra.GetUserById(id:, next:) ->
      run_test_program(next(find_user_by_id(db, id)), ctx, db)
    auth_algebra.ListUsers(pagination:, filters:, next:) ->
      run_test_program(next(find_users(db, pagination, filters)), ctx, db)
    auth_algebra.ListLoginTokensByEmail(email:, limit:, next:) ->
      run_test_program(
        next(find_login_tokens_by_email(db, email, limit)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByToken(token:, next:) ->
      run_test_program(
        next(find_hydrated_session(db, token, ctx.timestamp)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByTokenForUpdate(token:, next:) ->
      run_test_program(
        next(find_session_by_token(db, token, ctx.timestamp)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByPreviousToken(token:, next:) ->
      run_test_program(
        next(find_hydrated_session(db, token, ctx.timestamp)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByPreviousTokenForUpdate(token:, next:) ->
      run_test_program(
        next(find_session_by_token(db, token, ctx.timestamp)),
        ctx,
        db,
      )
    auth_algebra.CreateUser(user: user, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_user(db, user))
    auth_algebra.CreateAccount(account: account, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_account(db, account))
    auth_algebra.UpdateAccount(account: account, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_account(db, account))
    auth_algebra.UpdateUser(user: user, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_user(db, user))
    auth_algebra.DeleteSessionsByAccountId(account_id: account_id, next: next) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_sessions_by_account_id(db, account_id),
      )
    auth_algebra.DeleteUsersByAccountId(account_id: account_id, next: next) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_users_by_account_id(db, account_id),
      )
    auth_algebra.DeleteAccount(account_id: account_id, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, delete_account_by_id(db, account_id))
    auth_algebra.CreateSession(session: session, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_session(db, session))
    auth_algebra.UpdateSession(session: session, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, update_session(db, session))
    auth_algebra.DeleteSession(id: id, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, delete_session_by_id(db, id))
    auth_algebra.CreateLoginToken(login_token:, next:) -> {
      run_test_program(next(Ok(Nil)), ctx, upsert_login_token(db, login_token))
    }
    auth_algebra.UpdateLoginToken(login_token:, next:) ->
      run_test_program(next(Ok(Nil)), ctx, upsert_login_token(db, login_token))
    auth_algebra.DeleteLoginTokensBefore(before:, next:) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_login_tokens_before(db, before),
      )
  }
}

fn run_test_auth_tx_effect(
  effect: auth_algebra.AuthEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    auth_algebra.GetUserByEmail(email:, next:) ->
      run_test_tx_program(next(find_user_by_email(db, email)), ctx, db)
    auth_algebra.GetUserById(id:, next:) ->
      run_test_tx_program(next(find_user_by_id(db, id)), ctx, db)
    auth_algebra.ListUsers(pagination:, filters:, next:) ->
      run_test_tx_program(next(find_users(db, pagination, filters)), ctx, db)
    auth_algebra.ListLoginTokensByEmail(email:, limit:, next:) ->
      run_test_tx_program(
        next(find_login_tokens_by_email(db, email, limit)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByToken(token:, next:) ->
      run_test_tx_program(
        next(find_hydrated_session(db, token, ctx.timestamp)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByTokenForUpdate(token:, next:) ->
      run_test_tx_program(
        next(find_session_by_token(db, token, ctx.timestamp)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByPreviousToken(token:, next:) ->
      run_test_tx_program(
        next(find_hydrated_session(db, token, ctx.timestamp)),
        ctx,
        db,
      )
    auth_algebra.GetSessionByPreviousTokenForUpdate(token:, next:) ->
      run_test_tx_program(
        next(find_session_by_token(db, token, ctx.timestamp)),
        ctx,
        db,
      )
    auth_algebra.CreateUser(user: user, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_user(db, user))
    auth_algebra.CreateAccount(account: account, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_account(db, account))
    auth_algebra.UpdateAccount(account: account, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_account(db, account))
    auth_algebra.UpdateUser(user: user, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_user(db, user))
    auth_algebra.DeleteSessionsByAccountId(account_id: account_id, next: next) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_sessions_by_account_id(db, account_id),
      )
    auth_algebra.DeleteUsersByAccountId(account_id: account_id, next: next) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_users_by_account_id(db, account_id),
      )
    auth_algebra.DeleteAccount(account_id: account_id, next: next) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_account_by_id(db, account_id),
      )
    auth_algebra.CreateSession(session: session, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_session(db, session))
    auth_algebra.UpdateSession(session: session, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, update_session(db, session))
    auth_algebra.DeleteSession(id: id, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, delete_session_by_id(db, id))
    auth_algebra.CreateLoginToken(login_token:, next:) -> {
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        upsert_login_token(db, login_token),
      )
    }
    auth_algebra.UpdateLoginToken(login_token:, next:) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        upsert_login_token(db, login_token),
      )
    auth_algebra.DeleteLoginTokensBefore(before:, next:) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_login_tokens_before(db, before),
      )
  }
}

fn run_test_email_template_effect(
  effect: email_template_algebra.EmailTemplateEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    email_template_algebra.ListEmailTemplates(next:) ->
      run_test_program(next(list_email_templates(db)), ctx, db)
    email_template_algebra.GetEmailTemplateByName(name:, next:) ->
      run_test_program(next(find_email_template_by_name(db, name)), ctx, db)
    email_template_algebra.UpdateEmailTemplate(template:, next:) ->
      run_test_program(next(Nil), ctx, update_email_template(db, template))
  }
}

fn run_test_email_template_tx_effect(
  effect: email_template_algebra.EmailTemplateEffect(
    program_types.TransactionProgram(a),
  ),
  _ctx: context.Context,
  _db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    email_template_algebra.ListEmailTemplates(_)
    | email_template_algebra.GetEmailTemplateByName(_, _)
    | email_template_algebra.UpdateEmailTemplate(_, _) ->
      panic as "Email template tx effects are not used in backend tests"
  }
}

fn run_test_job_effect(
  effect: job_algebra.JobEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_algebra.ListJobs(filter:, pagination:, next:) -> {
      let _ = filter
      let _ = pagination
      run_test_program(next([]), ctx, db)
    }
    job_algebra.SummarizeJobs(filter:, now:, next:) -> {
      let _ = filter
      let _ = now
      run_test_program(
        next(job_model.Summary(
          total_count: 0,
          pending_count: 0,
          running_count: 0,
          failed_count: 0,
          done_count: 0,
          overdue_count: 0,
        )),
        ctx,
        db,
      )
    }
    job_algebra.GetNextJob(now:, pending_status:, next:) -> {
      let _ = now
      let _ = pending_status
      run_test_program(next(option.None), ctx, db)
    }
    job_algebra.GetExpiredRunningJob(now:, running_status:, next:) ->
      run_test_program(next(find_expired_job(db, now, running_status)), ctx, db)
    job_algebra.GetJobById(id:, next:) ->
      run_test_program(next(find_job(db, id)), ctx, db)
    job_algebra.CreateJob(job, next) ->
      run_test_program(next(Ok(Nil)), ctx, put_job(db, job))
    job_algebra.UpdateJob(job, next) ->
      run_test_program(next(Ok(Nil)), ctx, put_job(db, job))
    job_algebra.DeleteJob(id, next) ->
      run_test_program(next(Ok(Nil)), ctx, delete_job_by_id(db, id))
    job_algebra.DeleteBefore(before:, statuses:, next:) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_jobs_before_by_statuses(db, before, statuses),
      )
  }
}

fn run_test_job_log_effect(
  effect: job_log_algebra.JobLogEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_log_algebra.DeleteJobLogBefore(before: _, next: next) ->
      run_test_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_job_tx_effect(
  effect: job_algebra.JobEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_algebra.ListJobs(filter:, pagination:, next:) -> {
      let _ = filter
      let _ = pagination
      run_test_tx_program(next([]), ctx, db)
    }
    job_algebra.SummarizeJobs(filter:, now:, next:) -> {
      let _ = filter
      let _ = now
      run_test_tx_program(
        next(job_model.Summary(
          total_count: 0,
          pending_count: 0,
          running_count: 0,
          failed_count: 0,
          done_count: 0,
          overdue_count: 0,
        )),
        ctx,
        db,
      )
    }
    job_algebra.GetNextJob(now:, pending_status:, next:) -> {
      let _ = now
      let _ = pending_status
      run_test_tx_program(next(option.None), ctx, db)
    }
    job_algebra.GetExpiredRunningJob(now:, running_status:, next:) ->
      run_test_tx_program(
        next(find_expired_job(db, now, running_status)),
        ctx,
        db,
      )
    job_algebra.GetJobById(id:, next:) ->
      run_test_tx_program(next(find_job(db, id)), ctx, db)
    job_algebra.CreateJob(job, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, put_job(db, job))
    job_algebra.UpdateJob(job, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, put_job(db, job))
    job_algebra.DeleteJob(id, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, delete_job_by_id(db, id))
    job_algebra.DeleteBefore(before:, statuses:, next:) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_jobs_before_by_statuses(db, before, statuses),
      )
  }
}

fn run_test_job_log_tx_effect(
  effect: job_log_algebra.JobLogEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    job_log_algebra.DeleteJobLogBefore(before: _, next: next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, db)
  }
}

fn run_test_snippet_effect(
  effect: snippet_algebra.SnippetEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    snippet_algebra.GetSnippetById(id, next) -> {
      let _ = id
      run_test_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.GetSnippetBySlug(slug, next) -> {
      let _ = slug
      run_test_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.GetAdminSnippetBySlug(slug: _, next:) -> {
      run_test_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.ListSnippets(filter: _, pagination: _, next: next) ->
      run_test_program(next(Ok([])), ctx, db)
    snippet_algebra.ListAdminSnippets(username: _, pagination: _, next: next) ->
      run_test_program(next(Ok([])), ctx, db)
    snippet_algebra.DeleteSnippet(id, next) ->
      run_test_program(next(Ok(Nil)), ctx, delete_snippet_by_id(db, id))
    snippet_algebra.DeleteSnippetsByAccountId(
      account_id: account_id,
      next: next,
    ) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_snippets_by_account_id(db, account_id),
      )
    snippet_algebra.CreateSnippet(snippet, next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_snippet(db, snippet))
    snippet_algebra.UpdateSnippet(snippet, next) ->
      run_test_program(next(Ok(Nil)), ctx, insert_snippet(db, snippet))
  }
}

fn run_test_snippet_tx_effect(
  effect: snippet_algebra.SnippetEffect(program_types.TransactionProgram(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    snippet_algebra.GetSnippetById(id, next) -> {
      let _ = id
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.GetSnippetBySlug(slug, next) -> {
      let _ = slug
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.GetAdminSnippetBySlug(slug: _, next:) -> {
      run_test_tx_program(next(Ok(option.None)), ctx, db)
    }
    snippet_algebra.ListSnippets(filter: _, pagination: _, next: next) ->
      run_test_tx_program(next(Ok([])), ctx, db)
    snippet_algebra.ListAdminSnippets(username: _, pagination: _, next: next) ->
      run_test_tx_program(next(Ok([])), ctx, db)
    snippet_algebra.DeleteSnippet(id, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, delete_snippet_by_id(db, id))
    snippet_algebra.DeleteSnippetsByAccountId(
      account_id: account_id,
      next: next,
    ) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_snippets_by_account_id(db, account_id),
      )
    snippet_algebra.CreateSnippet(snippet, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_snippet(db, snippet))
    snippet_algebra.UpdateSnippet(snippet, next) ->
      run_test_tx_program(next(Ok(Nil)), ctx, insert_snippet(db, snippet))
  }
}

fn run_test_user_action_effect(
  effect: user_action_algebra.UserActionEffect(program_types.Program(a)),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    user_action_algebra.CountUserActions(filter:, next:) -> {
      let _ = filter
      run_test_program(next([]), ctx, db)
    }
    user_action_algebra.CreateUserAction(user_action:, next:) -> {
      let _ = user_action
      run_test_program(next(Ok(Nil)), ctx, increment_user_action_count(db))
    }
    user_action_algebra.DeleteBefore(before:, next:) ->
      run_test_program(
        next(Ok(Nil)),
        ctx,
        delete_user_actions_before(db, before),
      )
  }
}

fn run_test_user_action_tx_effect(
  effect: user_action_algebra.UserActionEffect(
    program_types.TransactionProgram(a),
  ),
  ctx: context.Context,
  db: TestDb,
) -> #(Result(a, error.Error), TestDb) {
  case effect {
    user_action_algebra.CountUserActions(filter:, next:) -> {
      let _ = filter
      run_test_tx_program(next([]), ctx, db)
    }
    user_action_algebra.CreateUserAction(user_action:, next:) -> {
      let _ = user_action
      run_test_tx_program(next(Ok(Nil)), ctx, increment_user_action_count(db))
    }
    user_action_algebra.DeleteBefore(before:, next:) ->
      run_test_tx_program(
        next(Ok(Nil)),
        ctx,
        delete_user_actions_before(db, before),
      )
  }
}

fn pop_uuid(db: TestDb) -> #(uuid.Uuid, TestDb) {
  case db.next_uuids {
    [next, ..rest] -> #(next, TestDb(..db, next_uuids: rest))
    [] -> #(uuid.nil, db)
  }
}

fn find_job(db: TestDb, id: uuid.Uuid) -> option.Option(job_model.Job) {
  db.jobs
  |> dict.get(uuid_key(id))
  |> option.from_result()
}

fn find_expired_job(
  db: TestDb,
  now: timestamp.Timestamp,
  status: job_model.Status,
) -> option.Option(job_model.Job) {
  db.jobs
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(_, job) = entry
    job
  })
  |> list.filter(fn(job) {
    job.status == status
    && case job.lease_expires_at {
      option.Some(lease_expires_at) ->
        timestamp_helpers.to_microseconds(lease_expires_at)
        <= timestamp_helpers.to_microseconds(now)
      option.None -> False
    }
  })
  |> list.sort(fn(a, b) {
    case a.lease_expires_at, b.lease_expires_at {
      option.Some(a_lease), option.Some(b_lease) ->
        case
          timestamp_helpers.to_microseconds(a_lease)
          < timestamp_helpers.to_microseconds(b_lease)
        {
          True -> order.Lt
          False ->
            case
              timestamp_helpers.to_microseconds(a_lease)
              > timestamp_helpers.to_microseconds(b_lease)
            {
              True -> order.Gt
              False ->
                case
                  timestamp_helpers.to_microseconds(a.created_at)
                  < timestamp_helpers.to_microseconds(b.created_at)
                {
                  True -> order.Lt
                  False ->
                    case
                      timestamp_helpers.to_microseconds(a.created_at)
                      > timestamp_helpers.to_microseconds(b.created_at)
                    {
                      True -> order.Gt
                      False -> order.Eq
                    }
                }
            }
        }
      _, _ -> order.Eq
    }
  })
  |> list.first
  |> option.from_result()
}

fn find_job_type_policy(
  db: TestDb,
  job_type: job_model.JobType,
) -> option.Option(job_model.JobTypePolicy) {
  db.job_type_policies
  |> dict.get(job_model.job_type_to_string(job_type))
  |> option.from_result()
}

fn list_job_type_policies(db: TestDb) -> List(job_model.JobTypePolicy) {
  db.job_type_policies
  |> dict.to_list
  |> list.map(fn(entry) { entry.1 })
  |> list.sort(fn(a, b) {
    string.compare(
      job_model.job_type_to_string(a.job_type),
      job_model.job_type_to_string(b.job_type),
    )
  })
}

fn upsert_test_job_type_policy(
  db: TestDb,
  policy: job_model.JobTypePolicy,
) -> TestDb {
  TestDb(
    ..db,
    job_type_policies: dict.insert(
      db.job_type_policies,
      job_model.job_type_to_string(policy.job_type),
      policy,
    ),
  )
}

fn find_next_periodic_job(
  db: TestDb,
  now: timestamp.Timestamp,
) -> option.Option(periodic_job_model.PeriodicJob) {
  list_periodic_jobs(db)
  |> list.filter(fn(periodic_job) {
    periodic_job.enabled
    && timestamp_helpers.to_microseconds(periodic_job.next_run_at)
    <= timestamp_helpers.to_microseconds(now)
  })
  |> list.sort(fn(a, b) {
    case
      timestamp_helpers.to_microseconds(a.next_run_at)
      < timestamp_helpers.to_microseconds(b.next_run_at)
    {
      True -> order.Lt
      False ->
        case
          timestamp_helpers.to_microseconds(a.next_run_at)
          > timestamp_helpers.to_microseconds(b.next_run_at)
        {
          True -> order.Gt
          False ->
            case
              timestamp_helpers.to_microseconds(a.created_at)
              < timestamp_helpers.to_microseconds(b.created_at)
            {
              True -> order.Lt
              False ->
                case
                  timestamp_helpers.to_microseconds(a.created_at)
                  > timestamp_helpers.to_microseconds(b.created_at)
                {
                  True -> order.Gt
                  False -> order.Eq
                }
            }
        }
    }
  })
  |> list.first
  |> option.from_result
}

fn list_periodic_jobs(db: TestDb) -> List(periodic_job_model.PeriodicJob) {
  db.periodic_jobs
  |> dict.to_list
  |> list.map(fn(entry) {
    let #(_, periodic_job) = entry
    periodic_job
  })
}

fn find_periodic_job_by_id(
  db: TestDb,
  id: uuid.Uuid,
) -> option.Option(periodic_job_model.PeriodicJob) {
  db.periodic_jobs
  |> dict.get(uuid_key(id))
  |> option.from_result()
}

fn find_user_by_email(
  db: TestDb,
  email: email_address_model.EmailAddress,
) -> option.Option(user_model.HydratedUser) {
  case
    db.users
    |> dict.to_list
    |> list.find(fn(entry) {
      let #(_, user) = entry
      user.email == email
    })
    |> option.from_result()
  {
    option.Some(entry) -> {
      let #(_, user) = entry
      db.accounts
      |> dict.get(uuid_key(user.account_id))
      |> option.from_result()
      |> option.map(fn(account) {
        user_model.HydratedUser(
          identity: user,
          account: account_model.HydratedAccount(
            identity: account,
            delete_scheduled_at: option.None,
          ),
        )
      })
    }
    option.None -> option.None
  }
}

fn find_email_template_by_name(
  db: TestDb,
  name: email_template.EmailTemplateName,
) -> option.Option(email_template.EmailTemplate) {
  case dict.get(db.email_templates, email_template.to_db_name(name)) {
    Ok(template) -> option.Some(template)
    Error(_) -> option.None
  }
}

fn list_email_templates(db: TestDb) -> List(email_template.EmailTemplate) {
  db.email_templates
  |> dict.to_list
  |> list.map(fn(entry) { entry.1 })
}

fn update_email_template(
  db: TestDb,
  template: email_template.EmailTemplate,
) -> TestDb {
  let key = email_template.to_db_name(template.name)
  TestDb(..db, email_templates: dict.insert(db.email_templates, key, template))
}

fn find_user_by_id(
  db: TestDb,
  id: uuid.Uuid,
) -> option.Option(user_model.HydratedUser) {
  case dict.get(db.users, uuid_key(id)) {
    Ok(user) ->
      db.accounts
      |> dict.get(uuid_key(user.account_id))
      |> option.from_result()
      |> option.map(fn(account) {
        user_model.HydratedUser(
          identity: user,
          account: account_model.HydratedAccount(
            identity: account,
            delete_scheduled_at: option.None,
          ),
        )
      })
    Error(_) -> option.None
  }
}

fn find_users(
  db: TestDb,
  pagination: pagination_model.CursorPagination,
  _filters: auth_algebra.UserListFilters,
) -> List(user_model.HydratedUser) {
  let users =
    db.users
    |> dict.to_list
    |> list.sort(fn(a, b) {
      case string.compare(a.0, b.0) {
        order.Lt -> order.Gt
        order.Eq -> order.Eq
        order.Gt -> order.Lt
      }
    })
    |> list.map(fn(entry) { entry.1 })
    |> list.map(fn(user) {
      let assert Ok(account) = dict.get(db.accounts, uuid_key(user.account_id))
      user_model.HydratedUser(
        identity: user,
        account: account_model.HydratedAccount(
          identity: account,
          delete_scheduled_at: option.None,
        ),
      )
    })

  case pagination {
    pagination_model.InitialPage(limit) -> take_users(users, limit)
    pagination_model.AfterPage(cursor, limit) ->
      users
      |> list.filter(fn(user) {
        string.compare(
          uuid_key(user.identity.id),
          pagination_model.to_string(cursor),
        )
        == order.Lt
      })
      |> take_users(limit)
    pagination_model.BeforePage(cursor, limit) ->
      users
      |> list.filter(fn(user) {
        string.compare(
          uuid_key(user.identity.id),
          pagination_model.to_string(cursor),
        )
        == order.Gt
      })
      |> list.reverse
      |> take_users(limit)
      |> list.reverse
  }
}

fn take_users(
  users: List(user_model.HydratedUser),
  limit: Int,
) -> List(user_model.HydratedUser) {
  case limit <= 0 {
    True -> []
    False ->
      case users {
        [] -> []
        [first, ..rest] -> [first, ..take_users(rest, limit - 1)]
      }
  }
}

fn find_session(db: TestDb, session_id: String) -> session_model.Session {
  let assert Ok(session) = dict.get(db.sessions, session_id)
  session
}

fn find_login_tokens_by_email(
  db: TestDb,
  email: email_address_model.EmailAddress,
  limit: Int,
) -> List(login_token_model.LoginToken) {
  let _ = limit

  db.login_tokens
  |> dict.to_list
  |> list.filter(fn(entry) {
    let #(_, login_token) = entry
    login_token.email == email
  })
  |> list.map(fn(entry) {
    let #(_, login_token) = entry
    login_token
  })
}

fn find_hydrated_session(
  db: TestDb,
  token: String,
  now: timestamp.Timestamp,
) -> option.Option(session_model.HydratedSession) {
  case find_session_by_token(db, token, now) {
    option.Some(session) ->
      case dict.get(db.users, uuid_key(session.user_id)) {
        Ok(user) ->
          case dict.get(db.accounts, uuid_key(user.account_id)) {
            Ok(account) ->
              option.Some(session_model.HydratedSession(
                identity: session,
                user: user_model.HydratedUser(
                  identity: user,
                  account: account_model.HydratedAccount(
                    identity: account,
                    delete_scheduled_at: option.None,
                  ),
                ),
              ))
            Error(_) -> option.None
          }
        Error(_) -> option.None
      }
    option.None -> option.None
  }
}

fn find_session_by_token(
  db: TestDb,
  token: String,
  now: timestamp.Timestamp,
) -> option.Option(session_model.Session) {
  case dict.get(db.session_ids_by_token, token) {
    Ok(session_id) ->
      case dict.get(db.sessions, session_id) {
        Ok(session) -> option.Some(session)
        Error(_) -> option.None
      }
    Error(_) ->
      db.sessions
      |> dict.to_list
      |> list.find(fn(entry) {
        let #(_, session) = entry
        case session.previous_token, session.previous_token_valid_until {
          option.Some(previous_token), option.Some(valid_until) ->
            previous_token == token
            && timestamp_helpers.to_microseconds(valid_until)
            >= timestamp_helpers.to_microseconds(now)
          _, _ -> False
        }
      })
      |> option.from_result()
      |> option.map(fn(entry) {
        let #(_, session) = entry
        session
      })
  }
}

fn session_belongs_to_account(
  db: TestDb,
  session: session_model.Session,
  account_id: uuid.Uuid,
) -> Bool {
  case dict.get(db.users, uuid_key(session.user_id)) {
    Ok(user) -> user.account_id == account_id
    Error(_) -> False
  }
}

fn insert_user(db: TestDb, user: user_model.User) -> TestDb {
  TestDb(
    ..db,
    users: dict.insert(db.users, uuid_key(user.id), user),
    write_steps: ["create_user", ..db.write_steps],
  )
}

fn insert_account(db: TestDb, account: account_model.Account) -> TestDb {
  TestDb(
    ..db,
    accounts: dict.insert(db.accounts, uuid_key(account.id), account),
    write_steps: ["create_account", ..db.write_steps],
  )
}

fn insert_session(db: TestDb, session: session_model.Session) -> TestDb {
  TestDb(
    ..db,
    sessions: dict.insert(db.sessions, uuid_key(session.id), session),
    session_ids_by_token: dict.insert(
      db.session_ids_by_token,
      session.token,
      uuid_key(session.id),
    ),
    write_steps: ["create_session", ..db.write_steps],
  )
}

fn update_session(db: TestDb, session: session_model.Session) -> TestDb {
  let session_key = uuid_key(session.id)
  case dict.get(db.sessions, session_key) {
    Ok(previous_session) -> {
      TestDb(
        ..db,
        sessions: dict.insert(db.sessions, session_key, session),
        session_ids_by_token: db.session_ids_by_token
          |> dict.delete(previous_session.token)
          |> dict.insert(session.token, session_key),
        write_steps: ["update_session", ..db.write_steps],
      )
    }
    Error(_) -> db
  }
}

fn upsert_login_token(
  db: TestDb,
  login_token: login_token_model.LoginToken,
) -> TestDb {
  TestDb(
    ..db,
    login_tokens: dict.insert(
      db.login_tokens,
      uuid_key(login_token.id),
      login_token,
    ),
    write_steps: ["update_login_token", ..db.write_steps],
  )
}

fn delete_login_tokens_before(
  db: TestDb,
  before: timestamp.Timestamp,
) -> TestDb {
  let before_microseconds = timestamp_helpers.to_microseconds(before)
  let kept_login_tokens =
    db.login_tokens
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, login_token) = entry
      timestamp_helpers.to_microseconds(login_token.created_at)
      >= before_microseconds
    })
    |> dict.from_list

  TestDb(..db, login_tokens: kept_login_tokens)
}

fn delete_run_logs_before(db: TestDb, before: timestamp.Timestamp) -> TestDb {
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

  TestDb(..db, run_logs: kept_run_logs)
}

fn put_job(db: TestDb, job: job_model.Job) -> TestDb {
  TestDb(..db, jobs: dict.insert(db.jobs, uuid_key(job.id), job))
}

fn delete_jobs_before_by_statuses(
  db: TestDb,
  before: timestamp.Timestamp,
  statuses: List(job_model.Status),
) -> TestDb {
  let before_microseconds = timestamp_helpers.to_microseconds(before)
  let kept_jobs =
    db.jobs
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, job) = entry
      let completed_at_microseconds =
        job.completed_at
        |> option.map(timestamp_helpers.to_microseconds)

      case completed_at_microseconds {
        option.Some(completed_at) ->
          case
            completed_at < before_microseconds
            && list.contains(statuses, job.status)
          {
            True -> False
            False -> True
          }
        _ -> True
      }
    })
    |> dict.from_list

  TestDb(..db, jobs: kept_jobs)
}

fn put_periodic_job(
  db: TestDb,
  periodic_job: periodic_job_model.PeriodicJob,
) -> TestDb {
  TestDb(
    ..db,
    periodic_jobs: dict.insert(
      db.periodic_jobs,
      uuid_key(periodic_job.id),
      periodic_job,
    ),
  )
}

fn insert_snippet(db: TestDb, snippet: snippet_model.Snippet) -> TestDb {
  TestDb(
    ..db,
    snippets: dict.insert(db.snippets, uuid_key(snippet.id), snippet),
  )
}

fn delete_sessions_by_account_id(db: TestDb, account_id: uuid.Uuid) -> TestDb {
  let kept_sessions =
    db.sessions
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, session) = entry
      !session_belongs_to_account(db, session, account_id)
    })
    |> dict.from_list
  let kept_session_ids_by_token =
    db.session_ids_by_token
    |> dict.to_list
    |> list.filter(fn(entry) {
      let #(_, session_id) = entry
      dict.get(kept_sessions, session_id) == Ok(find_session(db, session_id))
    })
    |> dict.from_list

  TestDb(
    ..db,
    sessions: kept_sessions,
    session_ids_by_token: kept_session_ids_by_token,
    deletion_steps: ["delete_sessions_by_account_id", ..db.deletion_steps],
  )
}

fn delete_users_by_account_id(db: TestDb, account_id: uuid.Uuid) -> TestDb {
  TestDb(
    ..db,
    users: remove_users_by_account_id(db.users, account_id),
    deletion_steps: ["delete_users_by_account_id", ..db.deletion_steps],
  )
}

fn delete_account_by_id(db: TestDb, account_id: uuid.Uuid) -> TestDb {
  TestDb(
    ..db,
    accounts: dict.delete(db.accounts, uuid_key(account_id)),
    deletion_steps: ["delete_account", ..db.deletion_steps],
  )
}

fn delete_session_by_id(db: TestDb, id: uuid.Uuid) -> TestDb {
  let session_key = uuid_key(id)
  let session_ids_by_token = case dict.get(db.sessions, session_key) {
    Ok(session) -> dict.delete(db.session_ids_by_token, session.token)
    Error(_) -> db.session_ids_by_token
  }

  TestDb(
    ..db,
    sessions: dict.delete(db.sessions, session_key),
    session_ids_by_token: session_ids_by_token,
  )
}

fn delete_job_by_id(db: TestDb, id: uuid.Uuid) -> TestDb {
  TestDb(..db, jobs: dict.delete(db.jobs, uuid_key(id)))
}

fn delete_snippet_by_id(db: TestDb, id: BitArray) -> TestDb {
  TestDb(..db, snippets: dict.delete(db.snippets, bit_array_key(id)))
}

fn delete_snippets_by_account_id(db: TestDb, account_id: uuid.Uuid) -> TestDb {
  TestDb(
    ..db,
    snippets: remove_snippets_by_account_id(db, account_id),
    deletion_steps: ["delete_snippets_by_account_id", ..db.deletion_steps],
  )
}

fn increment_user_action_count(db: TestDb) -> TestDb {
  TestDb(..db, user_action_count: db.user_action_count + 1, write_steps: [
    "create_user_action",
    ..db.write_steps
  ])
}

fn delete_user_actions_before(
  db: TestDb,
  before: timestamp.Timestamp,
) -> TestDb {
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

  TestDb(..db, user_actions: kept_user_actions)
}

fn remove_users_by_account_id(
  users: Dict(String, user_model.User),
  account_id: uuid.Uuid,
) -> Dict(String, user_model.User) {
  users
  |> dict.to_list
  |> list.filter(fn(entry) {
    let #(_, user) = entry
    user.account_id != account_id
  })
  |> dict.from_list
}

fn remove_snippets_by_account_id(
  db: TestDb,
  account_id: uuid.Uuid,
) -> Dict(String, snippet_model.Snippet) {
  db.snippets
  |> dict.to_list
  |> list.filter(fn(entry) {
    let #(_, snippet) = entry
    case dict.get(db.users, uuid_key(snippet.user_id)) {
      Ok(user) -> user.account_id != account_id
      Error(_) -> True
    }
  })
  |> dict.from_list
}

fn uuid_key(id: uuid.Uuid) -> String {
  uuid.to_string(id)
}

fn bit_array_key(id: BitArray) -> String {
  let assert Ok(uuid) = uuid.from_bit_array(id)
  uuid_key(uuid)
}

fn must_uuid(value: String) -> uuid.Uuid {
  let assert Ok(id) = uuid.from_string(value)
  id
}

fn test_request_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000001")
}

fn test_account_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000010")
}

fn test_email_address() -> email_address_model.EmailAddress {
  email_address_model.EmailAddress("user@example.com")
}

fn test_user_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000011")
}

fn test_session_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000012")
}

fn test_snippet_id() -> uuid.Uuid {
  must_uuid("00000000-0000-0000-0000-000000000013")
}

fn test_timestamp() -> timestamp.Timestamp {
  timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0)
}

fn test_system_time() -> timestamp.Timestamp {
  timestamp.from_unix_seconds_and_nanoseconds(1_700_000_005, 0)
}

fn add_seconds(
  ts: timestamp.Timestamp,
  seconds_to_add: Int,
) -> timestamp.Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(seconds + seconds_to_add, nanos)
}

fn test_context() -> context.Context {
  let assert Ok(is_email) = regexp.from_string(".*")

  context.Context(
    config: context.Config(
      encryption_key: "test",
      static_base_path: "/tmp",
      postgres: context.PostgresConfig(
        host: "localhost",
        port: 5432,
        db: "test",
        user: "test",
        pass: "test",
        pool_size: 1,
      ),
    ),
    regexes: context.Regexes(is_email: is_email),
    request_id: uuid.nil,
    started_at: 0,
    deadline_at_monotonic_ns: option.None,
    timestamp: timestamp.system_time(),
    client_info: context.ClientInfo(
      session_token: option.None,
      ip: option.None,
      user_agent: option.None,
      referrer: option.None,
    ),
  )
}
