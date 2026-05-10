import gleam/dynamic/decode
import gleam/json
import glot_core/helpers/uuid_helpers
import youid/uuid

pub type DeleteAccountRequest {
  DeleteAccountRequest(user_id: uuid.Uuid)
}

pub fn delete_request_decoder() -> decode.Decoder(DeleteAccountRequest) {
  use user_id <- decode.field("userId", uuid_helpers.decoder())
  decode.success(DeleteAccountRequest(user_id: user_id))
}

pub fn encode_delete_request(request: DeleteAccountRequest) -> json.Json {
  json.object([#("userId", request.user_id |> uuid.to_string |> json.string)])
}
