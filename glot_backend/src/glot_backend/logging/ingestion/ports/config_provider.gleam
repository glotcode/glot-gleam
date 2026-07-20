import glot_backend/logging/ingestion/model/config.{type Config}

pub type ConfigProvider {
  ConfigProvider(load: fn() -> Result(Config, String))
}
