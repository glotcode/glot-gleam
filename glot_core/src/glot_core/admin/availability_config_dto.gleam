import gleam/dynamic/decode
import gleam/json
import gleam/option
import glot_core/availability_mode as availability_mode

pub type AvailabilityConfigResponse {
  AvailabilityConfigResponse(
    mode: availability_mode.AvailabilityMode,
    message: String,
    retry_after_seconds: option.Option(Int),
  )
}

pub type UpsertAvailabilityConfigRequest {
  UpsertAvailabilityConfigRequest(
    mode: availability_mode.AvailabilityMode,
    message: String,
    retry_after_seconds: option.Option(Int),
  )
}

pub fn response_decoder() -> decode.Decoder(AvailabilityConfigResponse) {
  use mode <- decode.field("mode", availability_mode.decoder())
  use message <- decode.field("message", decode.string)
  use retry_after_seconds <- decode.optional_field(
    "retry_after_seconds",
    option.None,
    decode.optional(decode.int),
  )
  decode.success(AvailabilityConfigResponse(
    mode: mode,
    message: message,
    retry_after_seconds: retry_after_seconds,
  ))
}

pub fn decoder() -> decode.Decoder(UpsertAvailabilityConfigRequest) {
  use mode <- decode.field("mode", availability_mode.decoder())
  use message <- decode.field("message", decode.string)
  use retry_after_seconds <- decode.optional_field(
    "retry_after_seconds",
    option.None,
    decode.optional(decode.int),
  )
  decode.success(UpsertAvailabilityConfigRequest(
    mode: mode,
    message: message,
    retry_after_seconds: retry_after_seconds,
  ))
}

pub fn encode_response(response: AvailabilityConfigResponse) -> json.Json {
  json.object([
    #("mode", availability_mode.encode(response.mode)),
    #("message", json.string(response.message)),
    #(
      "retry_after_seconds",
      json.nullable(response.retry_after_seconds, json.int),
    ),
  ])
}

pub fn encode_request(request: UpsertAvailabilityConfigRequest) -> json.Json {
  json.object([
    #("mode", availability_mode.encode(request.mode)),
    #("message", json.string(request.message)),
    #(
      "retry_after_seconds",
      json.nullable(request.retry_after_seconds, json.int),
    ),
  ])
}
