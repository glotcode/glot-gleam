import gleam/erlang/process
import gleam/option.{type Option}
import glot_backend/effect/handlers
import glot_backend/helpers/db_helpers
import glot_backend/worker/app_config_cache_worker/worker as app_config_cache_worker
import glot_backend/worker/language_version_cache_worker/worker as language_version_cache_worker
import pog

pub type Runtime {
  Runtime(
    db: Option(pog.Connection),
    handlers: handlers.Handlers,
    app_config_cache_subject: Option(
      process.Subject(app_config_cache_worker.Message),
    ),
    language_version_cache_subject: Option(
      process.Subject(language_version_cache_worker.Message),
    ),
  )
}

pub fn new(
  connection: pog.Connection,
  app_config_cache_subject: process.Subject(app_config_cache_worker.Message),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
) -> Runtime {
  Runtime(
    db: option.Some(connection),
    handlers: handlers.new(db_helpers.new(connection)),
    app_config_cache_subject: option.Some(app_config_cache_subject),
    language_version_cache_subject: option.Some(language_version_cache_subject),
  )
}

pub fn from_handlers(handlers: handlers.Handlers) -> Runtime {
  Runtime(
    db: option.None,
    handlers: handlers,
    app_config_cache_subject: option.None,
    language_version_cache_subject: option.None,
  )
}

pub fn from_parts(
  db: Option(pog.Connection),
  handlers: handlers.Handlers,
  app_config_cache_subject: Option(
    process.Subject(app_config_cache_worker.Message),
  ),
  language_version_cache_subject: Option(
    process.Subject(language_version_cache_worker.Message),
  ),
) -> Runtime {
  Runtime(
    db: db,
    handlers: handlers,
    app_config_cache_subject: app_config_cache_subject,
    language_version_cache_subject: language_version_cache_subject,
  )
}

pub fn with_timeout(runtime: Runtime, timeout_ms: Option(Int)) -> Runtime {
  case runtime.db {
    option.Some(connection) ->
      Runtime(
        ..runtime,
        handlers: handlers.new(
          db_helpers.new(connection)
          |> db_helpers.override_timeout(timeout_ms),
        ),
      )
    option.None -> runtime
  }
}
