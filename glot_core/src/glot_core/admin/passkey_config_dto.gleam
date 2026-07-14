import gleam/dynamic/decode
import gleam/json

pub type PasskeyConfigResponse {
  PasskeyConfigResponse(
    origin: String,
    rp_id: String,
    challenge_timeout_seconds: Int,
  )
}

pub type UpsertPasskeyConfigRequest {
  UpsertPasskeyConfigRequest(
    origin: String,
    rp_id: String,
    challenge_timeout_seconds: Int,
  )
}

pub fn response_decoder() -> decode.Decoder(PasskeyConfigResponse) {
  use origin <- decode.field("origin", decode.string)
  use rp_id <- decode.field("rpId", decode.string)
  use challenge_timeout_seconds <- decode.field(
    "challengeTimeoutSeconds",
    decode.int,
  )
  decode.success(PasskeyConfigResponse(
    origin:,
    rp_id:,
    challenge_timeout_seconds:,
  ))
}

pub fn decoder() -> decode.Decoder(UpsertPasskeyConfigRequest) {
  use origin <- decode.field("origin", decode.string)
  use rp_id <- decode.field("rpId", decode.string)
  use challenge_timeout_seconds <- decode.field(
    "challengeTimeoutSeconds",
    decode.int,
  )
  decode.success(UpsertPasskeyConfigRequest(
    origin:,
    rp_id:,
    challenge_timeout_seconds:,
  ))
}

pub fn encode_response(response: PasskeyConfigResponse) -> json.Json {
  json.object([
    #("origin", json.string(response.origin)),
    #("rpId", json.string(response.rp_id)),
    #("challengeTimeoutSeconds", json.int(response.challenge_timeout_seconds)),
  ])
}

pub fn encode_request(request: UpsertPasskeyConfigRequest) -> json.Json {
  json.object([
    #("origin", json.string(request.origin)),
    #("rpId", json.string(request.rp_id)),
    #("challengeTimeoutSeconds", json.int(request.challenge_timeout_seconds)),
  ])
}
