import gleam/erlang/process
import gleam/option
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/run_code/model/config as run_code_config
import glot_backend/run_code/worker/language_version_cache/worker as language_version_cache_worker
import glot_backend/system/effect/error/run_request_error
import glot_backend/system/lifecycle/server_mode/adapter/worker as server_mode_adapter
import glot_backend/system/lifecycle/server_mode/model as server_mode
import glot_backend/system/lifecycle/server_mode/worker as server_mode_worker
import glot_core/language
import glot_core/run
import support/process as test_process

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
  GetConfigReadCount(reply: process.Subject(Int))
  GetFetchCount(reply: process.Subject(Int))
  SetConfig(dynamic_config.DynamicConfig)
  SetNow(Int)
  GetNow(reply: process.Subject(Int))
}

type ControlState {
  ControlState(
    config: dynamic_config.DynamicConfig,
    config_read_count: Int,
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

  assert wait_for_fetch_count(control_subject, 1) == 1

  let fetch_reply = expect_fetch(control_subject)
  process.send(fetch_reply, Ok(successful_run("Python 3.13")))

  let first = expect_result(result_subject)
  let second = expect_result(result_subject)
  assert first == Ok(successful_run("Python 3.13"))
  assert second == Ok(successful_run("Python 3.13"))
  assert test_process.call(control_subject, GetFetchCount) == 1
}

pub fn stale_value_is_served_while_refresh_runs_test() {
  let control_name = process.new_name("language_cache_control")
  let worker_name = process.new_name("language_cache_worker")
  let control_subject = start_control(control_name)
  let #(worker_subject, _) =
    start_worker(worker_name, control_subject, [], server_mode.Running)
  let result_subject = process.new_subject()

  request_language_version(worker_subject, result_subject)
  let initial_fetch_reply = expect_fetch(control_subject)
  process.send(initial_fetch_reply, Ok(successful_run("Python 3.13")))
  assert expect_result(result_subject) == Ok(successful_run("Python 3.13"))

  process.send(control_subject, SetNow(3_600_000_000_001))

  let stale_result =
    language_version_cache_worker.get_language_version(
      worker_subject,
      language.Python,
    )
  assert stale_result == Ok(successful_run("Python 3.13"))

  let refresh_reply = expect_fetch(control_subject)
  process.send(refresh_reply, Ok(successful_run("Python 3.14")))

  assert wait_for_language_version(worker_subject)
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
  let initial_fetch_reply = expect_fetch(control_subject)
  process.send(initial_fetch_reply, Ok(successful_run("Python 3.13")))
  assert expect_result(result_subject) == Ok(successful_run("Python 3.13"))

  process.send(control_subject, SetNow(3_600_000_000_001))

  let stale_result =
    language_version_cache_worker.get_language_version(
      worker_subject,
      language.Python,
    )
  assert stale_result == Ok(successful_run("Python 3.13"))

  let refresh_reply = expect_fetch(control_subject)
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
  let #(_, server_mode_subject) =
    start_worker(
      worker_name,
      control_subject,
      [language.Python],
      server_mode.Maintenance,
    )

  assert wait_for_config_read_count(control_subject, 2) >= 2
  assert test_process.call(control_subject, GetFetchCount) == 0

  server_mode_worker.enter_running(server_mode_subject)

  assert wait_for_fetch_count(control_subject, 1) == 1
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

  assert wait_for_config_read_count(control_subject, 2) >= 2
  assert test_process.call(control_subject, GetFetchCount) == 0

  process.send(control_subject, SetConfig(config_with_docker_run()))

  assert wait_for_fetch_count(control_subject, 1) == 1
}

fn start_worker(
  worker_name: process.Name(language_version_cache_worker.Message),
  control_subject: process.Subject(ControlMessage),
  supported_languages: List(language.Language),
  mode: server_mode.Mode,
) -> #(
  process.Subject(language_version_cache_worker.Message),
  process.Subject(server_mode_worker.Message),
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
  process.Subject(server_mode_worker.Message),
) {
  let server_mode_name = process.new_name("language_cache_server_mode")
  let assert Ok(_) = server_mode_worker.start_in(server_mode_name, mode)
  let server_mode_subject = process.named_subject(server_mode_name)
  process.send(control_subject, SetConfig(initial_config))

  let handlers =
    language_version_cache_worker.Deps(
      fetch_language_version: fn(requested_language, _timeout_ms) {
        let response_subject = process.new_subject()
        process.send(
          control_subject,
          RegisterFetch(language: requested_language, reply: response_subject),
        )
        test_process.receive(response_subject)
      },
      get_config: fn() { Ok(test_process.call(control_subject, GetConfig)) },
      now_ns: fn() { test_process.call(control_subject, GetNow) },
      supported_languages: fn() { supported_languages },
    )

  let assert Ok(_) =
    language_version_cache_worker.start_with_deps(
      worker_name,
      server_mode_adapter.new(server_mode_subject),
      handlers,
    )
  #(process.named_subject(worker_name), server_mode_subject)
}

fn start_control(
  name: process.Name(ControlMessage),
) -> process.Subject(ControlMessage) {
  let subject = process.named_subject(name)
  let ready = process.new_subject()
  let _ =
    process.spawn(fn() {
      let assert Ok(Nil) = process.register(process.self(), name)
      process.send(ready, Nil)
      control_loop(
        subject,
        ControlState(
          config: dynamic_config.empty(),
          config_read_count: 0,
          fetch_count: 0,
          now_ns: 0,
          pending_fetches: [],
        ),
      )
    })
  let Nil = test_process.receive(ready)
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
      control_loop(
        subject,
        ControlState(..state, config_read_count: state.config_read_count + 1),
      )
    }
    GetConfigReadCount(reply) -> {
      process.send(reply, state.config_read_count)
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
) -> process.Subject(Result(run.RunResult, run_request_error.RunRequestError)) {
  let maybe_fetch =
    test_process.eventually(
      fn() { test_process.call(control_subject, TakeFetch) },
      fn(result) {
        case result {
          option.Some(_) -> True
          option.None -> False
        }
      },
    )
  let assert option.Some(fetch_reply) = maybe_fetch
  fetch_reply
}

fn wait_for_fetch_count(
  control_subject: process.Subject(ControlMessage),
  expected_count: Int,
) -> Int {
  test_process.eventually(
    fn() { test_process.call(control_subject, GetFetchCount) },
    fn(fetch_count) { fetch_count == expected_count },
  )
}

fn wait_for_config_read_count(
  control_subject: process.Subject(ControlMessage),
  expected_count: Int,
) -> Int {
  test_process.eventually(
    fn() { test_process.call(control_subject, GetConfigReadCount) },
    fn(read_count) { read_count >= expected_count },
  )
}

fn wait_for_language_version(
  worker_subject: process.Subject(language_version_cache_worker.Message),
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  test_process.eventually(
    fn() {
      language_version_cache_worker.get_language_version(
        worker_subject,
        language.Python,
      )
    },
    fn(result) { result == Ok(successful_run("Python 3.14")) },
  )
}

fn expect_result(
  result_subject: process.Subject(
    Result(run.RunResult, run_request_error.RunRequestError),
  ),
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  test_process.receive(result_subject)
}

fn successful_run(stdout: String) -> run.RunResult {
  Ok(run.SuccessfulRun(duration: 1, stdout: stdout, stderr: "", error: ""))
}

fn config_with_docker_run() -> dynamic_config.DynamicConfig {
  dynamic_config.DynamicConfig(
    ..dynamic_config.empty(),
    docker_run: option.Some(run_code_config.DockerRunConfig(
      base_url: "http://docker-run",
      access_token: "token",
      default_timeout_ms: 60_000,
    )),
  )
}
