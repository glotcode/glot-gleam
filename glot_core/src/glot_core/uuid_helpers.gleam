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

pub fn raw_decoder() -> decode.Decoder(BitArray) {
  decode.string
  |> decode.then(fn(str) {
    case uuid.from_string(str) {
      Ok(u) -> decode.success(uuid.to_bit_array(u))
      Error(_) -> decode.failure(<<>>, "Invalid UUID string")
    }
  })
}

pub fn v7(timestamp: timestamp.Timestamp) -> uuid.Uuid {
  let #(sec, ns) = timestamp.to_unix_seconds_and_nanoseconds(timestamp)
  uuid.v7_from_millisec(sec * 1000 + ns / 1_000_000)
}

pub fn v7_bit_array(timestamp: timestamp.Timestamp) -> BitArray {
  let u = v7(timestamp)
  uuid.to_bit_array(u)
}

pub fn from_bit_array(bits: BitArray) -> uuid.Uuid {
  let assert Ok(id) = uuid.from_bit_array(bits)
  id
}

pub fn raw_to_string(bits: BitArray) -> String {
  let id = from_bit_array(bits)
  uuid.to_string(id)
}
