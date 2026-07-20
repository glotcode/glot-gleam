import gleam/erlang/process
import gleam/option
import glot_backend/app_config/adapter/cache/worker as app_config_worker_cache
import glot_backend/app_config/worker/cache/worker as app_config_cache_worker
import glot_backend/run_code/adapter/cache/worker as language_version_worker_cache
import glot_backend/run_code/worker/language_version_cache/worker as language_version_cache_worker
import glot_backend/system/effect/cache_ports

pub fn new(
  app_config_subject: process.Subject(app_config_cache_worker.Message),
  language_version_subject: process.Subject(
    language_version_cache_worker.Message,
  ),
) -> cache_ports.CachePorts {
  cache_ports.CachePorts(
    app_config_cache: option.Some(app_config_worker_cache.new(
      app_config_subject,
    )),
    language_version_cache: option.Some(language_version_worker_cache.new(
      language_version_subject,
    )),
  )
}
