import gleam/erlang/process
import gleam/otp/static_supervisor
import glot_backend/app_config/adapter/postgres/store as app_config_postgres_store
import glot_backend/app_config/ports/cache.{type Cache}
import glot_backend/app_config/worker/cache/worker as app_config_cache_worker
import glot_backend/job/adapter/executor as job_executor_adapter
import glot_backend/job/adapter/postgres/log_store as job_postgres_log_store
import glot_backend/job/ports/tracker.{type Tracker}
import glot_backend/job/worker/executor/worker as job_worker
import glot_backend/job/worker/tracker/worker as job_tracker_worker
import glot_backend/logging/ingestion/adapter/app_config/config_provider as logging_config_provider
import glot_backend/logging/ingestion/adapter/batcher as logging_batcher_adapter
import glot_backend/logging/ingestion/adapter/postgres/batch_store as logging_postgres_batch_store
import glot_backend/logging/ingestion/worker/batcher/worker as log_worker
import glot_backend/run_code/adapter/docker_run/client as docker_run_client
import glot_backend/run_code/worker/language_version_cache/worker as language_version_cache_worker
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/runtime.{type Runtime}
import glot_backend/system/lifecycle/database_health/adapter/postgres/checker as database_health_postgres_checker
import glot_backend/system/lifecycle/database_health/worker as database_health_worker
import glot_backend/system/lifecycle/request_tracker/worker as request_tracker_worker
import glot_backend/system/lifecycle/server_mode/model
import glot_backend/system/lifecycle/server_mode/ports/controller.{
  type Controller,
}
import glot_backend/system/lifecycle/server_mode/worker as server_mode_worker
import glot_backend/system/lifecycle/startup/adapter/postgres/runner as startup_postgres_runner
import glot_backend/system/lifecycle/startup/worker as startup_worker
import glot_backend/system/request/context
import mist
import pog

pub type Config {
  Config(
    postgres: pog.Config,
    db: pog.Connection,
    effect_runtime: Runtime,
    app_config_cache: Cache,
    job_tracker: Tracker,
    server_mode: Controller,
    migrations_directory: String,
    seeds_directory: String,
    app: context.Config,
    regexes: context.Regexes,
    log_worker_name: process.Name(log_worker.Message),
    job_tracker_name: process.Name(job_tracker_worker.Message),
    request_tracker_name: process.Name(request_tracker_worker.Message),
    server_mode_name: process.Name(server_mode_worker.Message),
    app_config_cache_worker_name: process.Name(app_config_cache_worker.Message),
    language_version_cache_worker_name: process.Name(
      language_version_cache_worker.Message,
    ),
    mist_builder: mist.Builder(mist.Connection, mist.ResponseData),
  )
}

pub fn start(config: Config) {
  let job_executor_deps =
    job_executor_adapter.new(
      config.effect_runtime,
      job_postgres_log_store.new(db_helpers.new(config.db)),
    )
  let logging_deps =
    logging_batcher_adapter.new(
      logging_config_provider.new(config.app_config_cache),
      logging_postgres_batch_store.new(config.db),
    )

  static_supervisor.new(static_supervisor.OneForAll)
  |> static_supervisor.add(pog.supervised(config.postgres))
  |> static_supervisor.add(server_mode_worker.supervised_in(
    config.server_mode_name,
    model.Maintenance,
  ))
  |> static_supervisor.add(database_health_worker.supervised(
    database_health_postgres_checker.new(config.db),
    config.server_mode,
  ))
  |> static_supervisor.add(startup_worker.supervised(
    startup_postgres_runner.new(
      config.db,
      config.migrations_directory,
      config.seeds_directory,
    ),
    config.server_mode,
  ))
  |> static_supervisor.add(app_config_cache_worker.supervised(
    config.app_config_cache_worker_name,
    app_config_postgres_store.new(db_helpers.new(config.db)),
    config.server_mode,
  ))
  |> static_supervisor.add(log_worker.supervised(
    config.log_worker_name,
    logging_deps,
  ))
  |> static_supervisor.add(language_version_cache_worker.supervised(
    config.language_version_cache_worker_name,
    config.app_config_cache,
    docker_run_client.new(),
    config.server_mode,
  ))
  |> static_supervisor.add(request_tracker_worker.supervised(
    config.request_tracker_name,
  ))
  |> static_supervisor.add(job_tracker_worker.supervised(
    config.job_tracker_name,
  ))
  |> static_supervisor.add(job_worker.supervised(
    config.app,
    config.regexes,
    config.server_mode,
    config.job_tracker,
    job_executor_deps,
  ))
  |> static_supervisor.add(mist.supervised(config.mist_builder))
  |> static_supervisor.start
}
