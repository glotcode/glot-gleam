import gleam/erlang/process
import gleam/option.{type Option}
import glot_backend/effect/handlers
import glot_backend/worker/app_config_cache_worker
import glot_backend/worker/language_version_cache_worker
import pog

pub type Runtime {
  Runtime(
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
  app_config_cache_subject: process.Subject(
    app_config_cache_worker.Message,
  ),
  language_version_cache_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
) -> Runtime {
  Runtime(
    handlers: handlers.new(connection),
    app_config_cache_subject: option.Some(app_config_cache_subject),
    language_version_cache_subject: option.Some(language_version_cache_subject),
  )
}

pub fn from_handlers(handlers: handlers.Handlers) -> Runtime {
  Runtime(
    handlers: handlers,
    app_config_cache_subject: option.None,
    language_version_cache_subject: option.None,
  )
}

pub fn from_parts(
  handlers: handlers.Handlers,
  app_config_cache_subject: Option(
    process.Subject(app_config_cache_worker.Message),
  ),
  language_version_cache_subject: Option(
    process.Subject(language_version_cache_worker.Message),
  ),
) -> Runtime {
  Runtime(
    handlers: handlers,
    app_config_cache_subject: app_config_cache_subject,
    language_version_cache_subject: language_version_cache_subject,
  )
}
