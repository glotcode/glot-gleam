import gleam/result
import gleam/string
import glot_backend/app_config/model/config as dynamic_config
import glot_backend/app_config/ports/cache.{type Cache}
import glot_backend/logging/ingestion/model/config as logging_config
import glot_backend/logging/ingestion/ports/config_provider.{type ConfigProvider}

pub fn new(cache: Cache) -> ConfigProvider {
  config_provider.ConfigProvider(load: fn() {
    let #(result, _) = cache.lookup()
    result
    |> result.map(fn(config) {
      let source = dynamic_config.log_worker_config(config)
      logging_config.Config(
        flush_interval_ms: source.flush_interval_ms,
        max_batch_size: source.max_batch_size,
        max_buffer_size: source.max_buffer_size,
      )
    })
    |> result.map_error(string.inspect)
  })
}
