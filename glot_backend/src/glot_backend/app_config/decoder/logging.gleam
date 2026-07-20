import gleam/result
import glot_backend/app_config/decoder/value
import glot_backend/app_config/model/entry.{type AppConfigEntry}
import glot_backend/logging/ingestion/model/config.{type Config}

pub fn log_worker(
  current: Config,
  entry: AppConfigEntry,
) -> Result(Config, String) {
  use decoded <- result.try(value.int("log_worker", entry))

  case entry.key {
    "flush_interval_ms" ->
      Ok(config.Config(..current, flush_interval_ms: decoded))
    "max_batch_size" -> Ok(config.Config(..current, max_batch_size: decoded))
    "max_buffer_size" -> Ok(config.Config(..current, max_buffer_size: decoded))
    _ -> Ok(current)
  }
}
