import gleam/dict
import gleam/option
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/auth/domain/session/current as current_session
import glot_backend/auth/error as auth_error
import glot_backend/auth/model/config as auth_feature_config
import glot_backend/system/effect/error
import glot_backend/system/request/context
import glot_backend/system/request/hydrated_context as request_context
import glot_core/auth/session_model
import support/integration/fixture
import support/integration/model
import support/integration/profile/auth as runner
import support/integration/store/common

pub fn get_session_without_token_returns_none_test() {
  let ctx = fixture.test_context()

  let #(run_result, _) =
    runner.run_test_program(
      current_session.get_session(request_context.new(
        ctx,
        fixture.test_dynamic_config(),
      )),
      ctx,
      fixture.empty_test_state(),
    )

  assert run_result == Ok(option.None)
}

pub fn get_session_rejects_idle_expired_session_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let auth_config =
    auth_feature_config.AuthConfig(
      login_token_max_age: 86_400,
      session_token_max_age: 172_800,
      session_idle_timeout_seconds: 60,
      session_cookie_max_age: 86_400,
      session_refresh_interval_seconds: 300,
      session_previous_token_grace_seconds: 60,
      session_heartbeat_interval_seconds: 60,
    )
  let idle_session =
    session_model.Session(
      ..fixture.session,
      token_updated_at: fixture.add_seconds(fixture.test_timestamp(), 10),
      last_activity_at: fixture.add_seconds(fixture.test_timestamp(), 10),
    )
  let db =
    model.TestState(
      ..fixture.state,
      dynamic_config: dynamic_config.DynamicConfig(
        ..fixture.state.dynamic_config,
        auth: auth_config,
      ),
      sessions: dict.from_list([
        #(common.uuid_key(idle_session.id), idle_session),
      ]),
      session_ids_by_token: dict.from_list([
        #(idle_session.token, common.uuid_key(idle_session.id)),
      ]),
    )
  let ctx =
    context.Context(
      ..fixture.ctx,
      timestamp: fixture.add_seconds(fixture.test_timestamp(), 80),
    )

  let #(run_result, _) =
    runner.run_test_program(
      current_session.get_session(request_context.new(ctx, db.dynamic_config)),
      ctx,
      db,
    )

  assert run_result == Ok(option.None)
}

pub fn get_session_accepts_previous_token_within_grace_window_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = fixture.add_seconds(fixture.test_timestamp(), 30)
  let rotated_session =
    session_model.Session(
      ..fixture.session,
      token: "current-token",
      previous_token: option.Some("session-token"),
      previous_token_valid_until: option.Some(fixture.add_seconds(
        fixture.test_timestamp(),
        60,
      )),
      token_updated_at: fixture.test_timestamp(),
      last_activity_at: fixture.test_timestamp(),
    )
  let db =
    model.TestState(
      ..fixture.state,
      sessions: dict.from_list([
        #(common.uuid_key(rotated_session.id), rotated_session),
      ]),
      session_ids_by_token: dict.from_list([
        #(rotated_session.token, common.uuid_key(rotated_session.id)),
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
    runner.run_test_program(
      current_session.get_session(request_context.new(
        ctx,
        fixture.test_dynamic_config(),
      )),
      ctx,
      db,
    )

  let assert Ok(option.Some(session)) = run_result
  assert session.identity.id == rotated_session.id
  assert session.identity.token == "current-token"
}

pub fn get_session_rejects_previous_token_after_grace_window_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = fixture.add_seconds(fixture.test_timestamp(), 61)
  let rotated_session =
    session_model.Session(
      ..fixture.session,
      token: "current-token",
      previous_token: option.Some("session-token"),
      previous_token_valid_until: option.Some(fixture.add_seconds(
        fixture.test_timestamp(),
        60,
      )),
      token_updated_at: fixture.test_timestamp(),
      last_activity_at: fixture.test_timestamp(),
    )
  let db =
    model.TestState(
      ..fixture.state,
      sessions: dict.from_list([
        #(common.uuid_key(rotated_session.id), rotated_session),
      ]),
      session_ids_by_token: dict.from_list([
        #(rotated_session.token, common.uuid_key(rotated_session.id)),
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
    runner.run_test_program(
      current_session.get_session(request_context.new(ctx, db.dynamic_config)),
      ctx,
      db,
    )

  assert run_result == Ok(option.None)
}

pub fn get_session_with_missing_db_session_returns_none_test() {
  let ctx =
    context.Context(
      ..fixture.test_context(),
      client_info: context.ClientInfo(
        session_token: option.Some("missing-session-token"),
        ip: option.None,
        user_agent: option.None,
        referrer: option.None,
      ),
    )

  let #(run_result, _) =
    runner.run_test_program(
      current_session.get_session(request_context.new(
        ctx,
        fixture.test_dynamic_config(),
      )),
      ctx,
      fixture.empty_test_state(),
    )

  assert run_result == Ok(option.None)
}

pub fn require_session_without_token_returns_missing_token_error_test() {
  let ctx = fixture.test_context()

  let #(run_result, _) =
    runner.run_test_program(
      current_session.require_session(request_context.new(
        ctx,
        fixture.test_dynamic_config(),
      )),
      ctx,
      fixture.empty_test_state(),
    )

  assert run_result == Error(error.auth(auth_error.MissingSessionToken))
}

pub fn require_session_with_missing_db_session_returns_not_found_error_test() {
  let ctx =
    context.Context(
      ..fixture.test_context(),
      client_info: context.ClientInfo(
        session_token: option.Some("missing-session-token"),
        ip: option.None,
        user_agent: option.None,
        referrer: option.None,
      ),
    )

  let #(run_result, _) =
    runner.run_test_program(
      current_session.require_session(request_context.new(
        ctx,
        fixture.test_dynamic_config(),
      )),
      ctx,
      fixture.empty_test_state(),
    )

  assert run_result == Error(error.auth(auth_error.SessionNotFound))
}
