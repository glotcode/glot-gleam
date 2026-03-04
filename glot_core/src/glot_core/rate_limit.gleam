import gleam/time/timestamp.{type Timestamp}
import glot_core/timestamp_helpers

pub type TimeUnit {
  Daily
}

pub type Config {
  Config(time_unit: TimeUnit, max_requests: Int)
}

pub fn start_time(config: Config, now: Timestamp) -> Timestamp {
  case config.time_unit {
    Daily -> timestamp_helpers.one_day_ago(now)
  }
}
