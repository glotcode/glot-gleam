import gleam/json
import gleam/option
import gleam/regexp
import gleam/string
import gleam/time/timestamp
import gleeunit
import glot_backend/api
import glot_backend/app_config
import glot_backend/context
import glot_backend/crypto_token
import glot_backend/effect/admin_log/admin_log_handlers
import glot_backend/effect/analytics/analytics_handlers
import glot_backend/effect/api_log/api_log_handlers
import glot_backend/effect/app_config/app_config_handlers
import glot_backend/effect/auth/auth_handlers
import glot_backend/effect/basic/basic_algebra
import glot_backend/effect/basic/basic_effect
import glot_backend/effect/basic/basic_handlers
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/effect_trace
import glot_backend/effect/email/email_handlers
import glot_backend/effect/email_template/email_template_handlers
import glot_backend/effect/error
import glot_backend/effect/get_language_version/get_language_version_handlers
import glot_backend/effect/handlers
import glot_backend/effect/interpreter
import glot_backend/effect/job/job_handlers
import glot_backend/effect/job_log/job_log_handlers
import glot_backend/effect/job_type_policy/job_type_policy_handlers
import glot_backend/effect/page_log/page_log_handlers
import glot_backend/effect/pageview_log/pageview_log_handlers
import glot_backend/effect/periodic_job/periodic_job_handlers
import glot_backend/effect/program
import glot_backend/effect/run_log/run_log_handlers
import glot_backend/effect/runtime
import glot_backend/effect/snippet/snippet_handlers
import glot_backend/effect/transaction/transaction_algebra
import glot_backend/effect/transaction/transaction_handlers
import glot_backend/effect/user_action/user_action_handlers
import glot_backend/log
import glot_backend/server_timing
import glot_core/job/job_model
import glot_core/rate_limit
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn measurement_aggregation_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()
  let measured_effect = {
    use _ <- program.and_then(basic_effect.info(log.new()))
    use _ <- program.and_then(basic_effect.info(log.new()))
    program.succeed("ok")
  }

  let #(run_result, state) =
    interpreter.run(measured_effect, effect_runtime, ctx)

  assert run_result == Ok("ok")
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.LogEffectName(log.Info)),
      duration_ns: first,
      ..,
    ),
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.LogEffectName(log.Info)),
      duration_ns: second,
      ..,
    ),
  ] = state.effect_measurements
  assert first >= 0
  assert second >= 0
}

pub fn measures_effects_in_success_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()
  let measured_effect = {
    use _ <- program.and_then(basic_effect.new_token(
      5,
      crypto_token.AlphaNumeric,
    ))
    program.succeed("ok")
  }
  let #(run_result, state) =
    interpreter.run(measured_effect, effect_runtime, ctx)

  assert run_result == Ok("ok")
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
      duration_ns: duration_ms,
      ..,
    ),
  ] = state.effect_measurements
  assert duration_ms >= 0
}

pub fn measures_effects_in_error_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()
  let failing_effect = {
    use _ <- program.and_then(basic_effect.new_token(
      5,
      crypto_token.AlphaNumeric,
    ))
    program.fail(error.EmailInvalidError("bad"))
  }
  let #(run_result, state) =
    interpreter.run(failing_effect, effect_runtime, ctx)

  assert run_result == Error(error.EmailInvalidError("bad"))
  let assert [
    effect_trace.EffectMeasurement(
      name: effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
      duration_ns: duration_ms,
      ..,
    ),
  ] = state.effect_measurements
  assert duration_ms >= 0
}

pub fn suppressed_debug_log_is_not_stored_or_measured_test() {
  let effect_runtime = test_runtime()
  let ctx = test_context()
  let measured_effect = {
    use _ <- program.and_then(
      basic_effect.debug(
        log.from_list([log.string("debug_key", "debug_value")]),
      ),
    )
    program.succeed("ok")
  }

  let #(run_result, state) =
    interpreter.run(measured_effect, effect_runtime, ctx)

  assert run_result == Ok("ok")
  assert state.debug_fields == log.new()
  assert state.effect_measurements == []
}

pub fn rolled_back_transaction_effect_is_marked_test() {
  let rolled_back_measurement =
    effect_trace.EffectMeasurement(
      name: effect_trace.TransactionEffectName(
        transaction_algebra.RunEffectName,
        [
          effect_trace.EffectMeasurement(
            name: effect_trace.BasicEffectName(basic_algebra.NewTokenEffectName),
            category: effect_trace.UtilEffectCategory,
            duration_ns: 5,
          ),
        ],
        rolled_back: True,
      ),
      category: effect_trace.DbWriteEffectCategory,
      duration_ns: 10,
    )

  let encoded =
    rolled_back_measurement
    |> effect_trace.encode_effect_measurement
    |> json.to_string

  assert string.contains(encoded, "\"rolled_back\":true")

  let timing = server_timing.prepare([rolled_back_measurement], 10)
  assert string.contains(timing, "TxRollback;dur=")
}

pub fn api_error_status_mapping_test() {
  assert api.error_status(error.ValidationError("bad input")) == 400
  assert api.error_status(error.NotFoundError("snippet_not_found", "missing"))
    == 404
  assert api.error_status(error.ConflictError(
      "account_delete_not_scheduled",
      "no pending delete",
    ))
    == 409
  assert api.error_status(error.SessionError(error.MissingSessionTokenError))
    == 401
  assert api.error_status(error.AuthorizationError(error.NotOwnerError)) == 403
  assert api.error_status(error.TooManyRequestsError(3, test_rate_limit()))
    == 429
  assert api.error_status(
      error.RunError(error.InternalRunRequestError("docker unavailable")),
    )
    == 500
}

pub fn api_error_detail_codes_test() {
  assert api.api_error_details(error.LoginError(error.InvalidTokenError))
    == #(401, "login_invalid_token", "Invalid login token")
  assert api.api_error_details(error.LoginError(error.TokenUsedError))
    == #(409, "login_token_used", "Login token already used")
  assert api.api_error_details(error.SessionError(error.SessionExpiredError))
    == #(401, "session_expired", "Session expired")
  assert api.api_error_details(error.AuthorizationError(error.NotOwnerError))
    == #(403, "authorization_not_owner", "Not authorized")
  assert api.api_error_details(error.ValidationError(
      "files must contain at least one file",
    ))
    == #(
      400,
      "validation_files_missing",
      "files must contain at least one file",
    )
  assert api.api_error_details(error.ValidationError(
      "title must be at most 200 characters",
    ))
    == #(
      400,
      "validation_title_too_long",
      "title must be at most 200 characters",
    )
  assert api.api_error_details(error.ValidationError(
      "files[0].content must be at most 100000 characters",
    ))
    == #(
      400,
      "validation_files_0_content_too_long",
      "files[0].content must be at most 100000 characters",
    )
}

fn test_handlers() -> handlers.Handlers {
  handlers.Handlers(
    app_config: app_config_handlers.AppConfigHandlers(
      list_entries: fn() {
        Ok([
          app_config.AppConfigEntry(
            namespace: "debug",
            key: "enabled",
            value: "false",
          ),
        ])
      },
      upsert_entry: fn(_, _, _, _) { Ok(Nil) },
    ),
    admin_log: admin_log_handlers.AdminLogHandlers(
      list_api_logs: fn(_) { Ok([]) },
      get_api_log: fn(_) { Ok(option.None) },
      list_run_logs: fn(_) { Ok([]) },
      get_run_log: fn(_) { Ok(option.None) },
      list_job_logs: fn(_) { Ok([]) },
      get_job_log: fn(_) { Ok(option.None) },
    ),
    api_log: api_log_handlers.ApiLogHandlers(delete_before: fn(_) { Ok(Nil) }),
    analytics: analytics_handlers.AnalyticsHandlers(
      get_max_completed_metrics_day: fn() { Ok(option.None) },
      get_first_metrics_source_day: fn(_) { Ok(option.None) },
      insert_metrics_pageview_day: fn(_) { Ok(Nil) },
      insert_metrics_product_event_day: fn(_) { Ok(Nil) },
      insert_metrics_run_day: fn(_) { Ok(Nil) },
      insert_metrics_reliability_page_day: fn(_) { Ok(Nil) },
      insert_metrics_reliability_api_day: fn(_) { Ok(Nil) },
      insert_metrics_completed_day: fn(_) { Ok(Nil) },
    ),
    basic: basic_handlers.BasicHandlers(
      new_token: fn(_, _) { "random" },
      system_time: timestamp.system_time,
      uuid_v7: fn(_) { uuid.nil },
    ),
    email: email_handlers.EmailHandlers(send_email: fn(_) {
      Error(error.InternalSendEmailError("unused in test"))
    }),
    email_template: email_template_handlers.EmailTemplateHandlers(
      list_email_templates: fn() { Ok([]) },
      get_email_template_by_name: fn(_) { Ok(option.None) },
      update_email_template: fn(_) { Ok(Nil) },
    ),
    get_language_version: get_language_version_handlers.GetLanguageVersionHandlers(
      get_language_version: fn(_, _) {
        Error(error.InternalRunRequestError("unused in test"))
      },
    ),
    job: job_handlers.JobHandlers(
      list_jobs: fn(_, _) { Ok([]) },
      summarize_jobs: fn(_, _) {
        Ok(job_model.Summary(
          total_count: 0,
          pending_count: 0,
          running_count: 0,
          failed_count: 0,
          done_count: 0,
          overdue_count: 0,
        ))
      },
      get_next_job: fn(_: timestamp.Timestamp, _: job_model.Status) {
        Ok(option.None)
      },
      get_expired_running_job: fn(_: timestamp.Timestamp, _: job_model.Status) {
        Ok(option.None)
      },
      get_job_by_id: fn(_) { Ok(option.None) },
      create_job: fn(_) { Ok(Nil) },
      update_job: fn(_) { Ok(Nil) },
      delete_job: fn(_) { Ok(Nil) },
      delete_before: fn(_, _) { Ok(Nil) },
    ),
    job_log: job_log_handlers.JobLogHandlers(delete_before: fn(_) { Ok(Nil) }),
    job_type_policy: job_type_policy_handlers.JobTypePolicyHandlers(
      list_job_type_policies: fn() { Ok([]) },
      get_job_type_policy_by_job_type: fn(_) { Ok(option.None) },
      upsert_job_type_policy: fn(_, _) { Ok(Nil) },
    ),
    page_log: page_log_handlers.PageLogHandlers(delete_before: fn(_) { Ok(Nil) }),
    pageview_log: pageview_log_handlers.PageviewLogHandlers(
      delete_before: fn(_) { Ok(Nil) },
    ),
    periodic_job: periodic_job_handlers.PeriodicJobHandlers(
      list_periodic_jobs: fn() { Ok([]) },
      get_next_periodic_job: fn(_) { Ok(option.None) },
      get_periodic_job_by_id: fn(_) { Ok(option.None) },
      create_periodic_job: fn(_) { Ok(Nil) },
      update_periodic_job: fn(_) { Ok(Nil) },
    ),
    run_log: run_log_handlers.RunLogHandlers(
      create_run_log: fn(_) { Ok(Nil) },
      delete_before: fn(_) { Ok(Nil) },
    ),
    auth: auth_handlers.AuthHandlers(
      get_user_by_email: fn(_, _) { Ok(option.None) },
      get_user_by_id: fn(_, _) { Ok(option.None) },
      list_users: fn(_, _, _) { Ok([]) },
      list_login_tokens_by_email: fn(_, _) { Ok([]) },
      get_session_by_token: fn(_, _) { Ok(option.None) },
      create_user: fn(_) { Ok(Nil) },
      create_account: fn(_) { Ok(Nil) },
      update_account: fn(_) { Ok(Nil) },
      update_user: fn(_) { Ok(Nil) },
      delete_sessions_by_account_id: fn(_) { Ok(Nil) },
      delete_users_by_account_id: fn(_) { Ok(Nil) },
      delete_account: fn(_) { Ok(Nil) },
      create_session: fn(_) { Ok(Nil) },
      delete_session: fn(_) { Ok(Nil) },
      create_login_token: fn(_) { Ok(Nil) },
      update_login_token: fn(_) { Ok(Nil) },
      delete_login_tokens_before: fn(_) { Ok(Nil) },
    ),
    snippet: snippet_handlers.SnippetHandlers(
      get_snippet_by_id: fn(_) { Ok(option.None) },
      get_snippet_by_slug: fn(_) { Ok(option.None) },
      get_admin_snippet_by_slug: fn(_) { Ok(option.None) },
      list_snippets: fn(_, _) { Ok([]) },
      list_admin_snippets: fn(_, _) { Ok([]) },
      delete_snippet: fn(_) { Ok(Nil) },
      delete_snippets_by_account_id: fn(_) { Ok(Nil) },
      create_snippet: fn(_) { Ok(Nil) },
      update_snippet: fn(_) { Ok(Nil) },
    ),
    docker_run: docker_run_handlers.DockerRunHandlers(run_code: fn(_, _) {
      Error(error.InternalRunRequestError("unused in test"))
    }),
    user_action: user_action_handlers.UserActionHandlers(
      count_user_actions: fn(_) { Ok([]) },
      create_user_action: fn(_) { Ok(Nil) },
      delete_before: fn(_) { Ok(Nil) },
    ),
    transaction: transaction_handlers.none(),
  )
}

fn test_runtime() -> runtime.Runtime {
  runtime.from_handlers(test_handlers())
}

fn test_rate_limit() -> rate_limit.RateLimit {
  rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 2)
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
    timestamp: timestamp.system_time(),
    client_info: context.ClientInfo(
      session_token: option.None,
      ip: option.None,
      user_agent: option.None,
      referrer: option.None,
    ),
  )
}
