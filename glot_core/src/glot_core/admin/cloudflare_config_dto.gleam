import gleam/dynamic/decode
import gleam/json

pub type CloudflareConfigResponse {
  CloudflareConfigResponse(account_id: String, api_token: String)
}

pub type UpsertCloudflareConfigRequest {
  UpsertCloudflareConfigRequest(account_id: String, api_token: String)
}

pub fn response_decoder() -> decode.Decoder(CloudflareConfigResponse) {
  use account_id <- decode.field("accountId", decode.string)
  use api_token <- decode.field("apiToken", decode.string)
  decode.success(CloudflareConfigResponse(account_id:, api_token: api_token))
}

pub fn decoder() -> decode.Decoder(UpsertCloudflareConfigRequest) {
  use account_id <- decode.field("accountId", decode.string)
  use api_token <- decode.field("apiToken", decode.string)
  decode.success(UpsertCloudflareConfigRequest(
    account_id:,
    api_token: api_token,
  ))
}

pub fn encode_response(response: CloudflareConfigResponse) -> json.Json {
  json.object([
    #("accountId", json.string(response.account_id)),
    #("apiToken", json.string(response.api_token)),
  ])
}

pub fn encode_request(request: UpsertCloudflareConfigRequest) -> json.Json {
  json.object([
    #("accountId", json.string(request.account_id)),
    #("apiToken", json.string(request.api_token)),
  ])
}
