import gleam/dynamic/decode
import gleam/int
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

pub fn to_microseconds(ts: Timestamp) -> Int {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  seconds * 1_000_000 + nanos / 1_000
}

pub fn one_day_ago(now: Timestamp) -> Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(now)
  timestamp.from_unix_seconds_and_nanoseconds(seconds - 86_400, nanos)
}

pub fn one_hour_ago(now: Timestamp) -> Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(now)
  timestamp.from_unix_seconds_and_nanoseconds(seconds - 3600, nanos)
}

pub fn one_minute_ago(now: Timestamp) -> Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(now)
  timestamp.from_unix_seconds_and_nanoseconds(seconds - 60, nanos)
}

pub fn one_second_ago(now: Timestamp) -> Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(now)
  timestamp.from_unix_seconds_and_nanoseconds(seconds - 1, nanos)
}

pub fn duration_in_ns(a: Timestamp, b: Timestamp) -> Int {
  let #(a_seconds, a_nanos) = timestamp.to_unix_seconds_and_nanoseconds(a)
  let #(b_seconds, b_nanos) = timestamp.to_unix_seconds_and_nanoseconds(b)

  let a_total = a_seconds * 1_000_000_000 + a_nanos
  let b_total = b_seconds * 1_000_000_000 + b_nanos

  int.absolute_value(a_total - b_total)
}
