import gleam/dynamic/decode
import gleam/json
import gleam/time/timestamp.{type Timestamp}

pub fn encode(ts: Timestamp) -> json.Json {
  let #(secs, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  json.object([
    #("seconds", json.int(secs)),
    #("nanos", json.int(nanos)),
  ])
}

pub fn decoder() -> decode.Decoder(Timestamp) {
  use secs <- decode.field("seconds", decode.int)
  use nanos <- decode.field("nanos", decode.int)

  decode.success(timestamp.from_unix_seconds_and_nanoseconds(secs, nanos))
}

pub fn one_day_ago(now: Timestamp) -> Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(now)
  timestamp.from_unix_seconds_and_nanoseconds(seconds - 86_400, nanos)
}
