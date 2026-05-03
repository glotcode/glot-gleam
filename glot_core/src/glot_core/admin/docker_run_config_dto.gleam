import gleam/dynamic/decode
import gleam/json

pub type DockerRunConfigResponse {
  DockerRunConfigResponse(base_url: String, access_token: String)
}

pub type UpsertDockerRunConfigRequest {
  UpsertDockerRunConfigRequest(base_url: String, access_token: String)
}

pub fn response_decoder() -> decode.Decoder(DockerRunConfigResponse) {
  use base_url <- decode.field("baseUrl", decode.string)
  use access_token <- decode.field("accessToken", decode.string)
  decode.success(DockerRunConfigResponse(base_url:, access_token: access_token))
}

pub fn decoder() -> decode.Decoder(UpsertDockerRunConfigRequest) {
  use base_url <- decode.field("baseUrl", decode.string)
  use access_token <- decode.field("accessToken", decode.string)
  decode.success(UpsertDockerRunConfigRequest(base_url:, access_token: access_token))
}

pub fn encode_response(response: DockerRunConfigResponse) -> json.Json {
  json.object([
    #("baseUrl", json.string(response.base_url)),
    #("accessToken", json.string(response.access_token)),
  ])
}

pub fn encode_request(request: UpsertDockerRunConfigRequest) -> json.Json {
  json.object([
    #("baseUrl", json.string(request.base_url)),
    #("accessToken", json.string(request.access_token)),
  ])
}
