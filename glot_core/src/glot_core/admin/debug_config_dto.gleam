import gleam/dynamic/decode
import gleam/json

pub type DebugConfigResponse {
  DebugConfigResponse(enabled: Bool)
}

pub type UpsertDebugConfigRequest {
  UpsertDebugConfigRequest(enabled: Bool)
}

pub fn response_decoder() -> decode.Decoder(DebugConfigResponse) {
  use enabled <- decode.field("enabled", decode.bool)
  decode.success(DebugConfigResponse(enabled: enabled))
}

pub fn decoder() -> decode.Decoder(UpsertDebugConfigRequest) {
  use enabled <- decode.field("enabled", decode.bool)
  decode.success(UpsertDebugConfigRequest(enabled: enabled))
}

pub fn encode_response(response: DebugConfigResponse) -> json.Json {
  json.object([#("enabled", json.bool(response.enabled))])
}

pub fn encode_request(request: UpsertDebugConfigRequest) -> json.Json {
  json.object([#("enabled", json.bool(request.enabled))])
}
