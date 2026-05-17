import gleam/dynamic/decode
import gleam/json
import glot_core/helpers/uuid_helpers
import youid/uuid

pub type ApiError {
  ApiError(code: String, message: String, request_id: uuid.Uuid)
}

pub fn encode(error: ApiError) -> json.Json {
  json.object([
    #(
      "error",
      json.object([
        #("code", json.string(error.code)),
        #("message", json.string(error.message)),
        #("requestId", json.string(uuid.to_string(error.request_id))),
      ]),
    ),
  ])
}

pub fn decoder() -> decode.Decoder(ApiError) {
  use error <- decode.field("error", decode_error())
  decode.success(error)
}

fn decode_error() -> decode.Decoder(ApiError) {
  use code <- decode.field("code", decode.string)
  use message <- decode.field("message", decode.string)
  use request_id <- decode.field("requestId", uuid_helpers.decoder())
  decode.success(ApiError(code:, message:, request_id:))
}
