import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type EmailConfigResponse {
  EmailConfigResponse(
    from_address: String,
    from_name: option.Option(String),
    contact_address: option.Option(String),
    default_timeout_ms: Int,
  )
}

pub type UpsertEmailConfigRequest {
  UpsertEmailConfigRequest(
    from_address: String,
    from_name: option.Option(String),
    contact_address: option.Option(String),
    default_timeout_ms: Int,
  )
}

pub fn response_decoder() -> decode.Decoder(EmailConfigResponse) {
  use from_address <- decode.field("fromAddress", decode.string)
  use from_name <- decode.optional_field(
    "fromName",
    option.None,
    decode.optional(decode.string),
  )
  use default_timeout_ms <- decode.field("defaultTimeoutMs", decode.int)
  use contact_address <- decode.optional_field(
    "contactAddress",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(EmailConfigResponse(
    from_address:,
    from_name: from_name,
    contact_address:,
    default_timeout_ms: default_timeout_ms,
  ))
}

pub fn decoder() -> decode.Decoder(UpsertEmailConfigRequest) {
  use from_address <- decode.field("fromAddress", decode.string)
  use from_name <- decode.optional_field(
    "fromName",
    option.None,
    decode.optional(decode.string),
  )
  use default_timeout_ms <- decode.field("defaultTimeoutMs", decode.int)
  use contact_address <- decode.optional_field(
    "contactAddress",
    option.None,
    decode.optional(decode.string),
  )
  decode.success(UpsertEmailConfigRequest(
    from_address:,
    from_name: from_name,
    contact_address:,
    default_timeout_ms: default_timeout_ms,
  ))
}

pub fn encode_response(response: EmailConfigResponse) -> json.Json {
  json.object([
    #("fromAddress", json.string(response.from_address)),
    #("fromName", json.nullable(response.from_name, json.string)),
    #("contactAddress", json.nullable(response.contact_address, json.string)),
    #("defaultTimeoutMs", json.int(response.default_timeout_ms)),
  ])
}

pub fn encode_request(request: UpsertEmailConfigRequest) -> json.Json {
  json.object([
    #("fromAddress", json.string(request.from_address)),
    #("fromName", json.nullable(request.from_name, json.string)),
    #("contactAddress", json.nullable(request.contact_address, json.string)),
    #("defaultTimeoutMs", json.int(request.default_timeout_ms)),
  ])
}
