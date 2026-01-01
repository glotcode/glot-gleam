import gleam/dynamic/decode
import gleam/time/timestamp
import youid/uuid

pub fn decoder() -> decode.Decoder(uuid.Uuid) {
  decode.string
  |> decode.then(fn(str) {
    case uuid.from_string(str) {
      Ok(u) -> decode.success(u)
      Error(_) -> decode.failure(uuid.nil, "Invalid UUID string")
    }
  })
}

pub fn v7(timestamp: timestamp.Timestamp) -> uuid.Uuid {
  let #(sec, ns) = timestamp.to_unix_seconds_and_nanoseconds(timestamp)
  uuid.v7_from_millisec(sec * 1000 + ns / 1_000_000)
}
