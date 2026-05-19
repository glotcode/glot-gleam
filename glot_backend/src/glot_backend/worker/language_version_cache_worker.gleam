import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import glot_backend/context
import glot_backend/dynamic_config
import glot_backend/effect/docker_run/docker_run_handlers
import glot_backend/effect/error/db_error
import glot_backend/effect/error/run_request_error
import glot_backend/erlang
import glot_backend/server_mode
import glot_backend/worker/app_config_cache_worker
import glot_backend/worker/language_version_cache_worker_core as core
import glot_core/language as language_module
import glot_core/run
import wisp

const call_timeout_ms = 5000

pub type Message {
  GetLanguageVersion(
    language: language_module.Language,
    reply: process.Subject(
      Result(run.RunResult, run_request_error.RunRequestError),
    ),
  )
  RefreshConfig
  Tick
  RefreshNext
  FetchCompleted(
    language: language_module.Language,
    fetched_at_ns: Int,
    result: Result(run.RunResult, run_request_error.RunRequestError),
  )
}

pub type Deps {
  Deps(
    fetch_language_version: fn(
      process.Subject(app_config_cache_worker.Message),
      language_module.Language,
      Int,
    ) -> Result(run.RunResult, run_request_error.RunRequestError),
    get_config: fn(process.Subject(app_config_cache_worker.Message)) ->
      Result(dynamic_config.DynamicConfig, db_error.DbQueryError),
    now_ns: fn() -> Int,
    supported_languages: fn() -> List(language_module.Language),
  )
}

type State {
  State(
    subject: process.Subject(Message),
    app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
    server_mode_subject: process.Subject(server_mode.Message),
    deps: Deps,
    core: core.State,
  )
}

pub fn start(
  name: process.Name(Message),
  config: context.Config,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
) {
  start_with_handlers(
    name,
    config,
    app_config_cache_subject,
    server_mode_subject,
    default_deps(),
  )
}

pub fn start_with_handlers(
  name: process.Name(Message),
  _config: context.Config,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
  deps: Deps,
) {
  actor.new_with_initialiser(1000, fn(subject) {
    let initial_state =
      State(
        subject: subject,
        app_config_cache_subject: app_config_cache_subject,
        server_mode_subject: server_mode_subject,
        deps: deps,
        core: core.new(),
      )
    let _ = process.send(subject, RefreshConfig)
    let _ = process.send(subject, Tick)
    let initialised = actor.initialised(initial_state)
    Ok(actor.returning(initialised, Nil))
  })
  |> actor.named(name)
  |> actor.on_message(handle_message)
  |> actor.start
}

pub fn supervised(
  name: process.Name(Message),
  config: context.Config,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  server_mode_subject: process.Subject(server_mode.Message),
) {
  supervision.worker(fn() {
    start(name, config, app_config_cache_subject, server_mode_subject)
  })
}

pub fn get_language_version(
  subject: process.Subject(Message),
  language: language_module.Language,
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  process.call(subject, call_timeout_ms, fn(reply) {
    GetLanguageVersion(language:, reply:)
  })
}

fn default_deps() -> Deps {
  Deps(
    fetch_language_version: fetch_language_version,
    get_config: app_config_cache_worker.get_config,
    now_ns: erlang.perf_counter_ns,
    supported_languages: language_module.list,
  )
}

fn handle_message(
  state: State,
  message: Message,
) -> actor.Next(State, Message) {
  case message {
    GetLanguageVersion(language, reply) -> {
      let #(next_core, commands) =
        core.on_get_language_version(
          state.core,
          language,
          reply,
          state.deps.now_ns(),
          can_fetch(state),
          can_update_languages(state),
        )
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
    RefreshConfig -> actor.continue(refresh_config(state))
    Tick -> {
      let state = refresh_config(state)
      let #(next_core, commands) =
        core.on_tick(
          state.core,
          state.deps.supported_languages(),
          state.deps.now_ns(),
          can_update_languages(state),
        )
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
    RefreshNext -> {
      let #(next_core, commands) =
        core.on_refresh_next(state.core, can_update_languages(state))
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
    FetchCompleted(language, fetched_at_ns, result) -> {
      let #(next_core, commands) =
        core.on_fetch_completed(state.core, language, fetched_at_ns, result)
      actor.continue(run_commands(State(..state, core: next_core), commands))
    }
  }
}

fn fetch_language_version(
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language: language_module.Language,
  timeout_ms: Int,
) -> Result(run.RunResult, run_request_error.RunRequestError) {
  app_config_cache_worker.get_config(app_config_cache_subject)
  |> result.map_error(map_query_error)
  |> result.try(fn(config) {
    case dynamic_config.docker_run_config(config) {
      option.Some(docker_run) ->
        docker_run_handlers.run_code(
          docker_run,
          run_request(language),
          timeout_ms,
        )
      option.None -> {
        wisp.log_warning("Missing docker_run app_config")
        Error(run_request_error.ServerRunRequestError)
      }
    }
  })
}

fn run_request(language: language_module.Language) -> run.RunRequest {
  run.RunRequest(
    image: language_module.container_image(language),
    payload: run.RunRequestPayload(
      run_instructions: language_module.version_run_instructions(language),
      files: [],
      stdin: option.None,
    ),
  )
}

fn map_query_error(
  err: db_error.DbQueryError,
) -> run_request_error.RunRequestError {
  let db_error.DbQueryError(message: message) = err
  wisp.log_warning("Failed to load language version config: " <> message)
  run_request_error.ServerRunRequestError
}

fn refresh_config(state: State) -> State {
  case state.deps.get_config(state.app_config_cache_subject) {
    Ok(config) ->
      State(..state, core: core.set_config(state.core, config))
    Error(err) -> {
      let db_error.DbQueryError(message: message) = err
      wisp.log_warning(
        "Failed to refresh language version cache worker config: " <> message,
      )
      state
    }
  }
}

fn run_commands(state: State, commands: List(core.Command)) -> State {
  list.fold(commands, state, fn(state: State, command) {
    case command {
      core.Reply(reply, result) -> {
        process.send(reply, result)
        state
      }
      core.StartFetch(language, timeout_ms) -> {
        let subject = state.subject
        let app_config_cache_subject = state.app_config_cache_subject
        let deps = state.deps
        let _ =
          process.spawn_unlinked(fn() {
            let result =
              deps.fetch_language_version(
                app_config_cache_subject,
                language,
                timeout_ms,
              )
            let fetched_at_ns = deps.now_ns()
            process.send(
              subject,
              FetchCompleted(language, fetched_at_ns:, result: result),
            )
          })
        state
      }
      core.ScheduleTick(delay_ms) -> {
        let _ = process.send_after(state.subject, delay_ms, Tick)
        state
      }
      core.ScheduleRefreshNext(base_delay_ms, step_delay_ms, max_jitter_ms) -> {
        let jitter_ms = int.random(max_jitter_ms + 1)
        let _ =
          process.send_after(
            state.subject,
            base_delay_ms + step_delay_ms + jitter_ms,
            RefreshNext,
          )
        state
      }
      core.LogRefreshError(language, err) -> {
        wisp.log_warning(
          "Failed to refresh language version cache for "
          <> language_module.to_string(language)
          <> ": "
          <> string_from_run_request_error(err),
        )
        state
      }
    }
  })
}

fn can_fetch(state: State) -> Bool {
  server_mode.get_mode(state.server_mode_subject) == server_mode.Running
}

fn can_update_languages(state: State) -> Bool {
  can_fetch(state) && core.docker_run_configured(state.core)
}

fn string_from_run_request_error(
  err: run_request_error.RunRequestError,
) -> String {
  case err {
    run_request_error.ClientRunRequestError(message) -> message
    run_request_error.ServerRunRequestError -> "server run request error"
  }
}
