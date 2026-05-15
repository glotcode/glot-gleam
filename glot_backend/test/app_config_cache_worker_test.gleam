import gleam/dict
import gleam/erlang/process
import gleam/option
import gleeunit
import glot_backend/dynamic_config
import glot_backend/effect/error
import glot_backend/server_mode
import glot_backend/worker/app_config_cache_worker
import glot_core/public_action
import glot_core/auth/account_model
import glot_core/rate_limit

pub fn main() -> Nil {
  gleeunit.main()
}

type ControlMessage {
  RegisterFetch(
    reply: process.Subject(
      Result(dynamic_config.DynamicConfig, error.DbQueryError),
    ),
  )
  TakeFetch(
    reply: process.Subject(
      option.Option(
        process.Subject(
          Result(dynamic_config.DynamicConfig, error.DbQueryError),
        ),
      ),
    ),
  )
  GetFetchCount(reply: process.Subject(Int))
  SetNow(Int)
  GetNow(reply: process.Subject(Int))
}

type ControlState {
  ControlState(
    fetch_count: Int,
    now_ns: Int,
    pending_fetches: List(
      process.Subject(Result(dynamic_config.DynamicConfig, error.DbQueryError)),
    ),
  )
}

pub fn concurrent_cold_misses_are_deduped_test() {
  let control_name = process.new_name("app_config_control")
  let worker_name = process.new_name("app_config_worker")
  let control_subject = start_control(control_name)
  let worker_subject = start_worker(worker_name, control_subject)
  let result_subject = process.new_subject()

  request_config(worker_subject, result_subject)
  request_config(worker_subject, result_subject)

  assert wait_for_fetch_count(control_subject, 1, 20) == 1

  let fetch_reply = expect_fetch(control_subject, 20)
  process.send(fetch_reply, Ok(test_dynamic_config()))

  let first = expect_result(result_subject)
  let second = expect_result(result_subject)
  assert first == Ok(test_dynamic_config())
  assert second == Ok(test_dynamic_config())
  assert process.call(control_subject, 100, GetFetchCount) == 1
}

pub fn stale_value_is_served_while_refresh_runs_test() {
  let control_name = process.new_name("app_config_control")
  let worker_name = process.new_name("app_config_worker")
  let control_subject = start_control(control_name)
  let worker_subject = start_worker(worker_name, control_subject)
  let result_subject = process.new_subject()

  request_config(worker_subject, result_subject)
  let initial_fetch_reply = expect_fetch(control_subject, 20)
  process.send(initial_fetch_reply, Ok(test_dynamic_config()))
  assert expect_result(result_subject) == Ok(test_dynamic_config())

  process.send(control_subject, SetNow(60_000_000_001))

  let stale_result = app_config_cache_worker.get_config(worker_subject)
  assert stale_result == Ok(test_dynamic_config())

  let refresh_reply = expect_fetch(control_subject, 20)
  process.send(refresh_reply, Ok(updated_dynamic_config()))

  assert wait_for_config(worker_subject, 20) == Ok(updated_dynamic_config())
}

pub fn failed_refresh_keeps_stale_value_test() {
  let control_name = process.new_name("app_config_control")
  let worker_name = process.new_name("app_config_worker")
  let control_subject = start_control(control_name)
  let worker_subject = start_worker(worker_name, control_subject)
  let result_subject = process.new_subject()

  request_config(worker_subject, result_subject)
  let initial_fetch_reply = expect_fetch(control_subject, 20)
  process.send(initial_fetch_reply, Ok(test_dynamic_config()))
  assert expect_result(result_subject) == Ok(test_dynamic_config())

  process.send(control_subject, SetNow(60_000_000_001))

  let stale_result = app_config_cache_worker.get_config(worker_subject)
  assert stale_result == Ok(test_dynamic_config())

  let refresh_reply = expect_fetch(control_subject, 20)
  process.send(refresh_reply, Error(error.DbQueryError("refresh failed")))

  assert app_config_cache_worker.get_config(worker_subject)
    == Ok(test_dynamic_config())
}

fn start_worker(
  worker_name: process.Name(app_config_cache_worker.Message),
  control_subject: process.Subject(ControlMessage),
) -> process.Subject(app_config_cache_worker.Message) {
  let server_mode_name = process.new_name("app_config_server_mode")
  let assert Ok(_) = server_mode.start(server_mode_name)
  let server_mode_subject = process.named_subject(server_mode_name)

  let handlers =
    app_config_cache_worker.FetchHandlers(
      fetch_config: fn() {
        let response_subject = process.new_subject()
        process.send(control_subject, RegisterFetch(reply: response_subject))
        process.receive_forever(response_subject)
      },
      now_ns: fn() { process.call(control_subject, 100, GetNow) },
    )

  let assert Ok(_) =
    app_config_cache_worker.start_with_handlers(
      worker_name,
      server_mode_subject,
      handlers,
    )
  process.named_subject(worker_name)
}

fn start_control(
  name: process.Name(ControlMessage),
) -> process.Subject(ControlMessage) {
  let subject = process.named_subject(name)
  let _ =
    process.spawn(fn() {
      let assert Ok(Nil) = process.register(process.self(), name)
      control_loop(
        subject,
        ControlState(fetch_count: 0, now_ns: 0, pending_fetches: []),
      )
    })
  subject
}

fn control_loop(
  subject: process.Subject(ControlMessage),
  state: ControlState,
) -> Nil {
  case process.receive_forever(subject) {
    RegisterFetch(reply) ->
      control_loop(
        subject,
        ControlState(
          ..state,
          fetch_count: state.fetch_count + 1,
          pending_fetches: [reply, ..state.pending_fetches],
        ),
      )
    TakeFetch(reply) -> {
      let #(maybe_fetch, pending_fetches) = case state.pending_fetches {
        [first, ..rest] -> #(option.Some(first), rest)
        [] -> #(option.None, [])
      }
      process.send(reply, maybe_fetch)
      control_loop(
        subject,
        ControlState(..state, pending_fetches: pending_fetches),
      )
    }
    GetFetchCount(reply) -> {
      process.send(reply, state.fetch_count)
      control_loop(subject, state)
    }
    SetNow(now_ns) ->
      control_loop(subject, ControlState(..state, now_ns: now_ns))
    GetNow(reply) -> {
      process.send(reply, state.now_ns)
      control_loop(subject, state)
    }
  }
}

fn request_config(
  worker_subject: process.Subject(app_config_cache_worker.Message),
  result_subject: process.Subject(
    Result(dynamic_config.DynamicConfig, error.DbQueryError),
  ),
) -> Nil {
  let _ =
    process.spawn_unlinked(fn() {
      let result = app_config_cache_worker.get_config(worker_subject)
      process.send(result_subject, result)
    })
  Nil
}

fn expect_fetch(
  control_subject: process.Subject(ControlMessage),
  attempts_remaining: Int,
) -> process.Subject(Result(dynamic_config.DynamicConfig, error.DbQueryError)) {
  let maybe_fetch = process.call(control_subject, 100, TakeFetch)

  case maybe_fetch {
    option.Some(fetch_reply) -> fetch_reply
    option.None -> {
      assert attempts_remaining > 0
      process.sleep(10)
      expect_fetch(control_subject, attempts_remaining - 1)
    }
  }
}

fn wait_for_fetch_count(
  control_subject: process.Subject(ControlMessage),
  expected_count: Int,
  attempts_remaining: Int,
) -> Int {
  let fetch_count = process.call(control_subject, 100, GetFetchCount)

  case fetch_count == expected_count || attempts_remaining <= 0 {
    True -> fetch_count
    False -> {
      process.sleep(10)
      wait_for_fetch_count(
        control_subject,
        expected_count,
        attempts_remaining - 1,
      )
    }
  }
}

fn wait_for_config(
  worker_subject: process.Subject(app_config_cache_worker.Message),
  attempts_remaining: Int,
) -> Result(dynamic_config.DynamicConfig, error.DbQueryError) {
  let result = app_config_cache_worker.get_config(worker_subject)

  case result == Ok(updated_dynamic_config()) {
    True -> result
    False -> {
      assert attempts_remaining > 0
      process.sleep(10)
      wait_for_config(worker_subject, attempts_remaining - 1)
    }
  }
}

fn expect_result(
  result_subject: process.Subject(
    Result(dynamic_config.DynamicConfig, error.DbQueryError),
  ),
) -> Result(dynamic_config.DynamicConfig, error.DbQueryError) {
  process.receive_forever(result_subject)
}

fn test_dynamic_config() -> dynamic_config.DynamicConfig {
  dynamic_config.DynamicConfig(
    debug: dynamic_config.DebugConfig(enabled: False),
    auth: dynamic_config.AuthConfig(
      login_token_max_age: 900,
      session_token_max_age: 86_400,
      session_cookie_max_age: 86_400,
    ),
    cleanup: dynamic_config.CleanupConfig(
      api_log_retention_days: 30,
      page_log_retention_days: 30,
      pageview_log_retention_days: 30,
      run_log_retention_days: 90,
      job_log_retention_days: 90,
      jobs_retention_days: 90,
      login_tokens_retention_days: 30,
      user_actions_retention_days: 90,
    ),
    docker_run: option.Some(dynamic_config.DockerRunConfig(
      base_url: "http://docker-run",
      access_token: "test-token",
    )),
    rate_limit_policies: dict.from_list([
      #(
        public_action.RunAction,
        dynamic_config.RateLimitPolicy(rules: [
          dynamic_config.RateLimitRule(
            match: dynamic_config.AnonymousMatch,
            limits: [
              rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 2),
            ],
          ),
          dynamic_config.RateLimitRule(
            match: dynamic_config.AuthenticatedMatch(
              account_tiers: option.Some([
                account_model.FreeTier,
              ]),
            ),
            limits: [
              rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 5),
            ],
          ),
        ]),
      ),
    ]),
  )
}

fn updated_dynamic_config() -> dynamic_config.DynamicConfig {
  dynamic_config.DynamicConfig(
    debug: dynamic_config.DebugConfig(enabled: True),
    auth: dynamic_config.AuthConfig(
      login_token_max_age: 900,
      session_token_max_age: 86_400,
      session_cookie_max_age: 86_400,
    ),
    cleanup: dynamic_config.CleanupConfig(
      api_log_retention_days: 30,
      page_log_retention_days: 30,
      pageview_log_retention_days: 30,
      run_log_retention_days: 90,
      job_log_retention_days: 90,
      jobs_retention_days: 90,
      login_tokens_retention_days: 30,
      user_actions_retention_days: 90,
    ),
    docker_run: option.Some(dynamic_config.DockerRunConfig(
      base_url: "http://docker-run-2",
      access_token: "updated-token",
    )),
    rate_limit_policies: dict.from_list([
      #(
        public_action.RunAction,
        dynamic_config.RateLimitPolicy(rules: [
          dynamic_config.RateLimitRule(
            match: dynamic_config.AuthenticatedMatch(account_tiers: option.None),
            limits: [
              rate_limit.RateLimit(unit: rate_limit.Minute, max_requests: 9),
            ],
          ),
        ]),
      ),
    ]),
  )
}
