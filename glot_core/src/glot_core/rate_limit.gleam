import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_core/helpers/timestamp_helpers

pub type TimeUnit {
  Day
  Hour
  Minute
  Second
}

pub type Window {
  Window(unit: TimeUnit, cutoff: Timestamp)
}

pub type WindowCount {
  WindowCount(unit: TimeUnit, count: Int)
}

pub fn encode_window(window: Window) -> json.Json {
  case window {
    Window(unit, cutoff) ->
      json.object([
        #("unit", json.string(unit_to_string(unit))),
        #(
          "cutoff",
          json.string(timestamp.to_rfc3339(cutoff, calendar.utc_offset)),
        ),
      ])
  }
}

pub fn encode_windows(windows: List(Window)) -> json.Json {
  json.array(windows, of: encode_window)
}

pub fn unit_to_string(unit: TimeUnit) -> String {
  case unit {
    Day -> "day"
    Hour -> "hour"
    Minute -> "minute"
    Second -> "second"
  }
}

pub fn unit_from_string(s: String) -> Option(TimeUnit) {
  case s {
    "day" -> option.Some(Day)
    "hour" -> option.Some(Hour)
    "minute" -> option.Some(Minute)
    "second" -> option.Some(Second)
    _ -> option.None
  }
}

pub type RateLimit {
  RateLimit(unit: TimeUnit, max_requests: Int)
}

pub fn encode_rate_limit(rate_limit: RateLimit) -> json.Json {
  json.object([
    #("unit", json.string(unit_to_string(rate_limit.unit))),
    #("maxRequests", json.int(rate_limit.max_requests)),
  ])
}

pub fn decoder() -> decode.Decoder(RateLimit) {
  use unit <- decode.field("unit", time_unit_decoder())
  use max_requests <- decode.field("maxRequests", decode.int)
  decode.success(RateLimit(unit:, max_requests:))
}

fn to_window(rate_limit: RateLimit, now: Timestamp) -> Window {
  Window(unit: rate_limit.unit, cutoff: start_time(rate_limit, now))
}

pub fn to_windows(
  rate_limits: List(RateLimit),
  now: Timestamp,
) -> List(Window) {
  rate_limits
  |> list.map(fn(rate_limit) { to_window(rate_limit, now) })
}

pub fn start_time(config: RateLimit, now: Timestamp) -> Timestamp {
  case config.unit {
    Day -> timestamp_helpers.one_day_ago(now)
    Hour -> timestamp_helpers.one_hour_ago(now)
    Minute -> timestamp_helpers.one_minute_ago(now)
    Second -> timestamp_helpers.one_second_ago(now)
  }
}

fn time_unit_decoder() -> decode.Decoder(TimeUnit) {
  use value <- decode.then(decode.string)
  case unit_from_string(value) {
    option.Some(unit) -> decode.success(unit)
    option.None -> decode.failure(Minute, "TimeUnit")
  }
}
