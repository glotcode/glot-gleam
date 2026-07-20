import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/run_code/model/config as run_code_config
import glot_backend/run_code/worker/language_version_cache/core as language_version_cache_worker_core
import glot_backend/system/cache/cache_outcome
import glot_backend/system/cache/worker/state as cache_worker_state
import glot_backend/system/cache/worker/support as cache_worker_support
import glot_backend/system/effect/error/run_request_error
import glot_core/language
import glot_core/run
import support/process as test_process

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
  assert test_process.receive(waiter)
    == cache_worker_support.Lookup(
      Error(run_request_error.ServerRunRequestError),
      cache_outcome.CacheMissJoined,
    )
  let language_version_cache_worker_core.State(cache:, refresh_language:, ..) =
    next_state
  assert dict.size(cache_worker_state.keyed_cache_entries(cache)) == 1
  assert dict.is_empty(cache_worker_state.keyed_in_flights(cache))
  assert refresh_language == option.None
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
