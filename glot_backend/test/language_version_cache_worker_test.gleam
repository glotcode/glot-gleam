import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option
import gleam/regexp
import gleam/time/timestamp
import gleeunit
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/error/run_request_error
import glot_backend/server_mode
import glot_backend/worker/cache_worker_state
import glot_backend/worker/cache_worker_support
import glot_backend/worker/language_version_cache_worker/core as language_version_cache_worker_core
import glot_backend/worker/language_version_cache_worker/worker as language_version_cache_worker
import glot_core/language
import glot_core/run
import youid/uuid

pub fn main() -> Nil {
  gleeunit.main()
}

type ControlMessage {
  RegisterFetch(
    language: language.Language,
    reply: process.Subject(
      Result(run.RunResult, run_request_error.RunRequestError),
    ),
  )
  TakeFetch(
    reply: process.Subject(
      option.Option(
        process.Subject(
          Result(run.RunResult, run_request_error.RunRequestError),
        ),
      ),
    ),
  )
  GetConfig(reply: process.Subject(dynamic_config.DynamicConfig))
  GetFetchCount(reply: process.Subject(Int))
  SetConfig(dynamic_config.DynamicConfig)
  SetNow(Int)
  GetNow(reply: process.Subject(Int))
}

type ControlState {
  ControlState(
    config: dynamic_config.DynamicConfig,
    fetch_count: Int,
    now_ns: Int,
    pending_fetches: List(
      process.Subject(Result(run.RunResult, run_request_error.RunRequestError)),
    ),
  )
}

pub fn concurrent_cold_misses_are_deduped_test() {
  let control_name = process.new_name("language_cache_control")
  let worker_name = process.new_name("language_cache_worker")
  let control_subject = start_control(control_name)
  let #(worker_subject, _) =
    start_worker(worker_name, control_subject, [], server_mode.Running)
  let result_subject = process.new_subject()

  request_language_version(worker_subject, result_subject)
  request_language_version(worker_subject, result_subject)

  assert wait_for_fetch_count(control_subject, 1, 20) == 1

  let fetch_reply = expect_fetch(control_subject, 20)
  process.send(fetch_reply, Ok(successful_run("Python 3.13")))

  let first = expect_result(result_subject)
  let second = expect_result(result_subject)
  assert first == Ok(successful_run("Python 3.13"))
  assert second == Ok(successful_run("Python 3.13"))
  assert process.call(control_subject, 100, GetFetchCount) == 1
}

pub fn stale_value_is_served_while_refresh_runs_test() {
  let control_name = process.new_name("language_cache_control")
  let worker_name = process.new_name("language_cache_worker")
  let control_subject = start_control(control_name)
  let #(worker_subject, _) =
    start_worker(worker_name, control_subject, [], server_mode.Running)
  let result_subject = process.new_subject()

  request_language_version(worker_subject, result_subject)
  let initial_fetch_reply = expect_fetch(control_subject, 20)
  process.send(initial_fetch_reply, Ok(successful_run("Python 3.13")))
  assert expect_result(result_subject) == Ok(successful_run("Python 3.13"))

  process.send(control_subject, SetNow(3_600_000_000_001))

  let stale_result =
    language_version_cache_worker.get_language_version(
      worker_subject,
      language.Python,
    )
  assert stale_result == Ok(successful_run("Python 3.13"))

  let refresh_reply = expect_fetch(control_subject, 20)
  process.send(refresh_reply, Ok(successful_run("Python 3.14")))

  assert wait_for_language_version(worker_subject, 20)
    == Ok(successful_run("Python 3.14"))
}

pub fn failed_refresh_keeps_stale_value_test() {
  let control_name = process.new_name("language_cache_control")
  let worker_name = process.new_name("language_cache_worker")
  let control_subject = start_control(control_name)
  let #(worker_subject, _) =
    start_worker(worker_name, control_subject, [], server_mode.Running)
  let result_subject = process.new_subject()

  request_language_version(worker_subject, result_subject)
  let initial_fetch_reply = expect_fetch(control_subject, 20)
  process.send(initial_fetch_reply, Ok(successful_run("Python 3.13")))
  assert expect_result(result_subject) == Ok(successful_run("Python 3.13"))

  process.send(control_subject, SetNow(3_600_000_000_001))

  let stale_result =
    language_version_cache_worker.get_language_version(
      worker_subject,
      language.Python,
    )
  assert stale_result == Ok(successful_run("Python 3.13"))

  let refresh_reply = expect_fetch(control_subject, 20)
  process.send(refresh_reply, Error(run_request_error.ServerRunRequestError))

  assert language_version_cache_worker.get_language_version(
      worker_subject,
      language.Python,
    )
    == Ok(successful_run("Python 3.13"))
}

pub fn maintenance_mode_does_not_schedule_refreshes_test() {
  let control_name = process.new_name("language_cache_control")
  let worker_name = process.new_name("language_cache_worker")
  let control_subject = start_control(control_name)
  let #(worker_subject, server_mode_subject) =
    start_worker(
      worker_name,
      control_subject,
      [language.Python],
      server_mode.Maintenance,
    )

  process.sleep(20)

  assert process.call(control_subject, 100, GetFetchCount) == 0
  assert language_version_cache_worker.get_language_version(
      worker_subject,
      language.Python,
    )
    == Error(run_request_error.ServerRunRequestError)
  assert process.call(control_subject, 100, GetFetchCount) == 0

  server_mode.enter_running(server_mode_subject)

  assert wait_for_fetch_count(control_subject, 1, 30) == 1
}

pub fn missing_docker_run_config_polls_until_config_exists_test() {
  let control_name = process.new_name("language_cache_control")
  let worker_name = process.new_name("language_cache_worker")
  let control_subject = start_control(control_name)
  let _ =
    start_worker_with_config(
      worker_name,
      control_subject,
      [language.Python],
      server_mode.Running,
      dynamic_config.empty(),
    )

  process.sleep(20)
  assert process.call(control_subject, 100, GetFetchCount) == 0

  process.send(control_subject, SetConfig(config_with_docker_run()))

  assert wait_for_fetch_count(control_subject, 1, 30) == 1
}

pub fn core_cold_miss_starts_fetch_test() {
  let reply = process.new_subject()
  let state =
    language_version_cache_worker_core.new()
    |> language_version_cache_worker_core.set_config(config_with_docker_run())
  let #(next_state, commands) =
    language_version_cache_worker_core.on_get(
      state,
      language.Python,
      reply,
      0,
      True,
      True,
    )

  assert count_start_fetch(commands) == 1
  assert count_reply(commands) == 0
  let language_version_cache_worker_core.State(cache:, ..) = next_state
  assert dict.size(cache_worker_state.keyed_in_flights(cache)) == 1
}

pub fn core_tick_enqueues_initial_refresh_immediately_test() {
  let state =
    language_version_cache_worker_core.new()
    |> language_version_cache_worker_core.set_config(config_with_docker_run())
  let #(next_state, commands) =
    language_version_cache_worker_core.on_tick(
      state,
      [language.Python],
      0,
      True,
    )

  assert count_start_fetch(commands) == 1
  assert count_schedule_tick(commands) == 1
  let language_version_cache_worker_core.State(refresh_language:, ..) =
    next_state
  assert refresh_language == option.Some(language.Python)
}

pub fn core_failed_refresh_keeps_stale_cache_test() {
  let waiter = process.new_subject()
  let state =
    language_version_cache_worker_core.State(
      config: dynamic_config.language_version_cache_worker_config(
        config_with_docker_run(),
      ),
      docker_run_configured: True,
      cache: cache_worker_state.Keyed(
        cache_entries: dict.from_list([
          #(
            language.Python,
            cache_worker_support.CacheEntry(
              value: successful_run("Python 3.13"),
              refreshed_at_ns: 0,
            ),
          ),
        ]),
        in_flights: dict.from_list([
          #(
            language.Python,
            cache_worker_support.new_in_flight(True)
              |> cache_worker_support.with_waiter(waiter),
          ),
        ]),
      ),
      refresh_queue: [],
      refresh_language: option.Some(language.Python),
    )
  let #(next_state, commands) =
    language_version_cache_worker_core.on_fetch_completed(
      state,
      language.Python,
      1,
      Error(run_request_error.ServerRunRequestError),
    )

  run_core_commands(commands)
  assert process.receive_forever(waiter)
    == Error(run_request_error.ServerRunRequestError)
  let language_version_cache_worker_core.State(cache:, refresh_language:, ..) =
    next_state
  assert dict.size(cache_worker_state.keyed_cache_entries(cache)) == 1
  assert dict.is_empty(cache_worker_state.keyed_in_flights(cache))
  assert refresh_language == option.None
}

fn start_worker(
  worker_name: process.Name(language_version_cache_worker.Message),
  control_subject: process.Subject(ControlMessage),
  supported_languages: List(language.Language),
  mode: server_mode.Mode,
) -> #(
  process.Subject(language_version_cache_worker.Message),
  process.Subject(server_mode.Message),
) {
  start_worker_with_config(
    worker_name,
    control_subject,
    supported_languages,
    mode,
    config_with_docker_run(),
  )
}

fn start_worker_with_config(
  worker_name: process.Name(language_version_cache_worker.Message),
  control_subject: process.Subject(ControlMessage),
  supported_languages: List(language.Language),
  mode: server_mode.Mode,
  initial_config: dynamic_config.DynamicConfig,
) -> #(
  process.Subject(language_version_cache_worker.Message),
  process.Subject(server_mode.Message),
) {
  let server_mode_name = process.new_name("language_cache_server_mode")
  let assert Ok(_) = server_mode.start_in(server_mode_name, mode)
  let server_mode_subject = process.named_subject(server_mode_name)
  process.send(control_subject, SetConfig(initial_config))

  let handlers =
    language_version_cache_worker.Deps(
      fetch_language_version: fn(_, requested_language, _timeout_ms) {
        let response_subject = process.new_subject()
        process.send(
          control_subject,
          RegisterFetch(language: requested_language, reply: response_subject),
        )
        process.receive_forever(response_subject)
      },
      get_config: fn(_) { Ok(process.call(control_subject, 100, GetConfig)) },
      now_ns: fn() { process.call(control_subject, 100, GetNow) },
      supported_languages: fn() { supported_languages },
    )

  let assert Ok(_) =
    language_version_cache_worker.start_with_handlers(
      worker_name,
      test_context().config,
      process.new_subject(),
      server_mode_subject,
      handlers,
    )
  #(process.named_subject(worker_name), server_mode_subject)
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
        ControlState(
          config: dynamic_config.empty(),
          fetch_count: 0,
          now_ns: 0,
          pending_fetches: [],
        ),
      )
    })
  subject
}

fn control_loop(
  subject: process.Subject(ControlMessage),
  state: ControlState,
) -> Nil {
  case process.receive_forever(subject) {
    RegisterFetch(_language, reply) ->
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
    GetConfig(reply) -> {
      process.send(reply, state.config)
      control_loop(subject, state)
    }
    GetFetchCount(reply) -> {
      process.send(reply, state.fetch_count)
      control_loop(subject, state)
    }
    SetConfig(config) ->
      control_loop(subject, ControlState(..state, config: config))
    SetNow(now_ns) ->
      control_loop(subject, ControlState(..state, now_ns: now_ns))
    GetNow(reply) -> {
      process.send(reply, state.now_ns)
      control_loop(subject, state)
    }
  }
}

fn request_language_version(
  worker_subject: process.Subject(language_version_cache_worker.Message),
  result_subject: process.Subject(
    Result(run.RunResult, run_request_error.RunRequestError),
  ),
) -> Nil {
  let _ =
    process.spawn_unlinked(fn() {
      let result =
        language_version_cache_worker.get_language_version(
          worker_subject,
          language.Python,
        )
      process.send(result_subject, result)
    })
  Nil
}

fn expect_fetch(
  control_subject: process.Subject(ControlMessage),
  attempts_remaining: Int,
) -> process.Subject(Result(run.RunResult, run_request_error.RunRequestError)) {
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

fn count_start_fetch(
  commands: List(language_version_cache_worker_core.Command),
) -> Int {
  list.length(
    list.filter(commands, fn(command) {
      case command {
        language_version_cache_worker_core.StartFetch(_, _) -> True
        _ -> False
      }
    }),
  )
}

fn count_reply(
  commands: List(language_version_cache_worker_core.Command),
) -> Int {
  list.length(
    list.filter(commands, fn(command) {
      case command {
        language_version_cache_worker_core.Reply(_, _) -> True
        _ -> False
      }
    }),
  )
}

fn count_schedule_tick(
  commands: List(language_version_cache_worker_core.Command),
) -> Int {
  list.length(
    list.filter(commands, fn(command) {
      case command {
        language_version_cache_worker_core.ScheduleTick(_) -> True
        _ -> False
      }
    }),
  )
}

fn run_core_commands(
  commands: List(language_version_cache_worker_core.Command),
) -> Nil {
  list.each(commands, fn(command) {
    case command {
      language_version_cache_worker_core.Reply(reply, result) ->
        process.send(reply, result)
      _ -> Nil
    }
  })
}

fn wait_for_language_version(
  worker_subject: process.Subject(language_version_cache_worker.Message),
  attempts_remaining: Int,
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  let result =
    language_version_cache_worker.get_language_version(
      worker_subject,
      language.Python,
    )

  case result == Ok(successful_run("Python 3.14")) {
    True -> result
    False -> {
      assert attempts_remaining > 0
      process.sleep(10)
      wait_for_language_version(worker_subject, attempts_remaining - 1)
    }
  }
}

fn expect_result(
  result_subject: process.Subject(
    Result(run.RunResult, run_request_error.RunRequestError),
  ),
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  process.receive_forever(result_subject)
}

fn successful_run(stdout: String) -> run.RunResult {
  Ok(run.SuccessfulRun(duration: 1, stdout: stdout, stderr: "", error: ""))
}

fn config_with_docker_run() -> dynamic_config.DynamicConfig {
  dynamic_config.DynamicConfig(
    ..dynamic_config.empty(),
    docker_run: option.Some(dynamic_config.DockerRunConfig(
      base_url: "http://docker-run",
      access_token: "token",
      default_timeout_ms: 60_000,
    )),
  )
}

fn test_context() -> context.Context {
  let assert Ok(is_email) = regexp.from_string(".*")

  context.Context(
    config: context.Config(
      app_env: context.Dev,
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
      passkey: context.default_passkey_config(),
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
