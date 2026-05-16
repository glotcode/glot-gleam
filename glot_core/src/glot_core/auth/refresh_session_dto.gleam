import gleam/dynamic/decode
import gleam/json

pub type RefreshSessionResponse {
  RefreshSessionResponse(next_heartbeat_in_seconds: Int)
}

pub fn encode(response: RefreshSessionResponse) -> json.Json {
  json.object([
    #("nextHeartbeatInSeconds", json.int(response.next_heartbeat_in_seconds)),
  ])
}

pub fn decoder() -> decode.Decoder(RefreshSessionResponse) {
  use next_heartbeat_in_seconds <- decode.field(
    "nextHeartbeatInSeconds",
    decode.int,
  )

  decode.success(RefreshSessionResponse(next_heartbeat_in_seconds:))
}
