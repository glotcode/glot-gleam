import gleam/erlang/process
import gleam/option
import gleam/regexp
import gleam/time/timestamp
import gleeunit
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/error/run_request_error
import glot_backend/server_mode
import glot_backend/worker/language_version_cache_worker
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
  GetFetchCount(reply: process.Subject(Int))
  SetNow(Int)
  GetNow(reply: process.Subject(Int))
}

type ControlState {
  ControlState(
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
  let worker_subject = start_worker(worker_name, control_subject, [])
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
  let worker_subject = start_worker(worker_name, control_subject, [])
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
  let worker_subject = start_worker(worker_name, control_subject, [])
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

fn start_worker(
  worker_name: process.Name(language_version_cache_worker.Message),
  control_subject: process.Subject(ControlMessage),
  supported_languages: List(language.Language),
) -> process.Subject(language_version_cache_worker.Message) {
  let server_mode_name = process.new_name("language_cache_server_mode")
  let assert Ok(_) = server_mode.start(server_mode_name)
  let server_mode_subject = process.named_subject(server_mode_name)

  let handlers =
    language_version_cache_worker.FetchHandlers(
      fetch_language_version: fn(_, requested_language, _timeout_ms) {
        let response_subject = process.new_subject()
        process.send(
          control_subject,
          RegisterFetch(language: requested_language, reply: response_subject),
        )
        process.receive_forever(response_subject)
      },
      get_config: fn(_) { Ok(dynamic_config.empty()) },
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
