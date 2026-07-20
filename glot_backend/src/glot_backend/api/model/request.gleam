import gleam/dynamic
import gleam/dynamic/decode
import glot_core/api_action

pub type ApiRequest {
  ApiRequest(action: api_action.ApiAction, data: dynamic.Dynamic, bytes: Int)
}

pub fn decoder(bytes: Int) -> decode.Decoder(ApiRequest) {
  use action <- decode.field("action", api_action.decoder())
  use data <- decode.field("data", decode.dynamic)
  decode.success(ApiRequest(action:, data:, bytes:))
}
