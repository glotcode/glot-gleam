import gleam/dynamic/decode
import gleam/json

pub type DockerRunConfigResponse {
  DockerRunConfigResponse(
    base_url: String,
    access_token: String,
    default_timeout_ms: Int,
  )
}

pub type UpsertDockerRunConfigRequest {
  UpsertDockerRunConfigRequest(
    base_url: String,
    access_token: String,
    default_timeout_ms: Int,
  )
}

pub fn response_decoder() -> decode.Decoder(DockerRunConfigResponse) {
  use base_url <- decode.field("baseUrl", decode.string)
  use access_token <- decode.field("accessToken", decode.string)
  use default_timeout_ms <- decode.field("defaultTimeoutMs", decode.int)
  decode.success(DockerRunConfigResponse(
    base_url:,
    access_token: access_token,
    default_timeout_ms: default_timeout_ms,
  ))
}

pub fn decoder() -> decode.Decoder(UpsertDockerRunConfigRequest) {
  use base_url <- decode.field("baseUrl", decode.string)
  use access_token <- decode.field("accessToken", decode.string)
  use default_timeout_ms <- decode.field("defaultTimeoutMs", decode.int)
  decode.success(UpsertDockerRunConfigRequest(
    base_url:,
    access_token: access_token,
    default_timeout_ms: default_timeout_ms,
  ))
}

pub fn encode_response(response: DockerRunConfigResponse) -> json.Json {
  json.object([
    #("baseUrl", json.string(response.base_url)),
    #("accessToken", json.string(response.access_token)),
    #("defaultTimeoutMs", json.int(response.default_timeout_ms)),
  ])
}

pub fn encode_request(request: UpsertDockerRunConfigRequest) -> json.Json {
  json.object([
    #("baseUrl", json.string(request.base_url)),
    #("accessToken", json.string(request.access_token)),
    #("defaultTimeoutMs", json.int(request.default_timeout_ms)),
  ])
}
