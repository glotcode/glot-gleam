import gleam/dict
import gleam/option
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/auth/domain/session/refresh as refresh_session_domain
import glot_backend/auth/error as auth_error
import glot_backend/auth/model/config as auth_feature_config
import glot_backend/system/effect/error
import glot_backend/system/request/context
import glot_backend/system/request/hydrated_context as request_context
import glot_core/auth/refresh_session_dto
import glot_core/auth/session_model
import support/integration/fixture
import support/integration/model
import support/integration/profile/auth as runner
import support/integration/store/auth
import support/integration/store/common

pub fn refresh_session_rotates_token_with_previous_token_grace_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = fixture.add_seconds(fixture.test_timestamp(), 301)
  let ctx = context.Context(..fixture.ctx, timestamp: now)

  let #(run_result, db) =
    runner.run_test_program(
      refresh_session_domain.refresh_session(request_context.new(
        ctx,
        fixture.state.dynamic_config,
      )),
      ctx,
      fixture.state,
    )

  assert run_result
    == Ok(refresh_session_domain.RefreshSessionResult(
      session_token: "random",
      session_cookie_max_age: 86_400,
      response: refresh_session_dto.RefreshSessionResponse(
        next_heartbeat_in_seconds: 60,
      ),
    ))

  let assert Ok(session) =
    dict.get(db.sessions, common.uuid_key(fixture.test_session_id()))
  assert session.token == "random"
  assert session.previous_token == option.Some("session-token")
  assert session.previous_token_valid_until
    == option.Some(fixture.add_seconds(now, 60))
  assert session.token_updated_at == now

  let current_lookup = auth.find_hydrated_session(db, "random", now)
  let previous_lookup = auth.find_hydrated_session(db, "session-token", now)
  assert current_lookup != option.None
  assert previous_lookup != option.None
}

pub fn refresh_session_is_noop_when_rotated_too_recently_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let now = fixture.add_seconds(fixture.test_timestamp(), 120)
  let ctx = context.Context(..fixture.ctx, timestamp: now)

  let #(run_result, db) =
    runner.run_test_program(
      refresh_session_domain.refresh_session(request_context.new(
        ctx,
        fixture.state.dynamic_config,
      )),
      ctx,
      fixture.state,
    )

  assert run_result
    == Ok(refresh_session_domain.RefreshSessionResult(
      session_token: "session-token",
      session_cookie_max_age: 86_400,
      response: refresh_session_dto.RefreshSessionResponse(
        next_heartbeat_in_seconds: 60,
      ),
    ))

  let assert Ok(session) =
    dict.get(db.sessions, common.uuid_key(fixture.test_session_id()))
  assert session.token == "session-token"
  assert session.previous_token == option.None
  assert session.previous_token_valid_until == option.None
  assert session.token_updated_at == fixture.test_timestamp()
  assert session.last_activity_at == now
}

pub fn refresh_session_uses_configured_heartbeat_cadence_test() {
  let fixture =
    fixture.integration_fixture(
      next_uuids: [],
      jobs: [],
      account_delete_job_id: option.None,
    )
  let auth_config =
    auth_feature_config.AuthConfig(
      login_token_max_age: 900,
      session_token_max_age: 86_400,
      session_idle_timeout_seconds: 86_400,
      session_cookie_max_age: 86_400,
      session_refresh_interval_seconds: 300,
      session_previous_token_grace_seconds: 60,
      session_heartbeat_interval_seconds: 17,
    )
  let db =
    model.TestState(
      ..fixture.state,
      dynamic_config: dynamic_config.DynamicConfig(
        ..fixture.state.dynamic_config,
        auth: auth_config,
      ),
    )
  let now = fixture.add_seconds(fixture.test_timestamp(), 301)
  let ctx = context.Context(..fixture.ctx, timestamp: now)

  let #(run_result, _) =
    runner.run_test_program(
      refresh_session_domain.refresh_session(request_context.new(
        ctx,
        db.dynamic_config,
      )),
      ctx,
      db,
    )

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
      refresh_session_domain.refresh_session(request_context.new(
        ctx,
        db.dynamic_config,
      )),
      ctx,
      db,
    )

  assert run_result == Error(error.auth(auth_error.SessionNotFound))
}
