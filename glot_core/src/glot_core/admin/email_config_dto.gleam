import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type EmailConfigResponse {
  EmailConfigResponse(
    from_address: String,
    from_name: option.Option(String),
  )
}

pub type UpsertEmailConfigRequest {
  UpsertEmailConfigRequest(
    from_address: String,
    from_name: option.Option(String),
  )
}

pub fn response_decoder() -> decode.Decoder(EmailConfigResponse) {
  use from_address <- decode.field("fromAddress", decode.string)
  use from_name <- decode.optional_field(
    "fromName",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(EmailConfigResponse(from_address:, from_name: from_name))
}

pub fn decoder() -> decode.Decoder(UpsertEmailConfigRequest) {
  use from_address <- decode.field("fromAddress", decode.string)
  use from_name <- decode.optional_field(
    "fromName",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(UpsertEmailConfigRequest(from_address:, from_name: from_name))
}

pub fn encode_response(response: EmailConfigResponse) -> json.Json {
  json.object([
    #("fromAddress", json.string(response.from_address)),
    #("fromName", json.nullable(response.from_name, json.string)),
  ])
}

pub fn encode_request(request: UpsertEmailConfigRequest) -> json.Json {
  json.object([
    #("fromAddress", json.string(request.from_address)),
    #("fromName", json.nullable(request.from_name, json.string)),
  ])
}
