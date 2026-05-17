import gleam/dynamic/decode
import gleam/json

pub type LanguageVersionCacheWorkerConfigResponse {
  LanguageVersionCacheWorkerConfigResponse(
    refresh_interval_ms: Int,
    refresh_step_delay_ms: Int,
    refresh_step_jitter_ms: Int,
    default_timeout_ms: Int,
  )
}

pub type UpsertLanguageVersionCacheWorkerConfigRequest {
  UpsertLanguageVersionCacheWorkerConfigRequest(
    refresh_interval_ms: Int,
    refresh_step_delay_ms: Int,
    refresh_step_jitter_ms: Int,
    default_timeout_ms: Int,
  )
}

pub fn response_decoder() -> decode.Decoder(
  LanguageVersionCacheWorkerConfigResponse,
) {
  use refresh_interval_ms <- decode.field("refreshIntervalMs", decode.int)
  use refresh_step_delay_ms <- decode.field("refreshStepDelayMs", decode.int)
  use refresh_step_jitter_ms <- decode.field(
    "refreshStepJitterMs",
    decode.int,
  )
  use default_timeout_ms <- decode.field("defaultTimeoutMs", decode.int)
  decode.success(LanguageVersionCacheWorkerConfigResponse(
    refresh_interval_ms: refresh_interval_ms,
    refresh_step_delay_ms: refresh_step_delay_ms,
    refresh_step_jitter_ms: refresh_step_jitter_ms,
    default_timeout_ms: default_timeout_ms,
  ))
}

pub fn decoder() -> decode.Decoder(
  UpsertLanguageVersionCacheWorkerConfigRequest,
) {
  use refresh_interval_ms <- decode.field("refreshIntervalMs", decode.int)
  use refresh_step_delay_ms <- decode.field("refreshStepDelayMs", decode.int)
  use refresh_step_jitter_ms <- decode.field(
    "refreshStepJitterMs",
    decode.int,
  )
  use default_timeout_ms <- decode.field("defaultTimeoutMs", decode.int)
  decode.success(UpsertLanguageVersionCacheWorkerConfigRequest(
    refresh_interval_ms: refresh_interval_ms,
    refresh_step_delay_ms: refresh_step_delay_ms,
    refresh_step_jitter_ms: refresh_step_jitter_ms,
    default_timeout_ms: default_timeout_ms,
  ))
}

pub fn encode_response(
  response: LanguageVersionCacheWorkerConfigResponse,
) -> json.Json {
  json.object([
    #("refreshIntervalMs", json.int(response.refresh_interval_ms)),
    #("refreshStepDelayMs", json.int(response.refresh_step_delay_ms)),
    #("refreshStepJitterMs", json.int(response.refresh_step_jitter_ms)),
    #("defaultTimeoutMs", json.int(response.default_timeout_ms)),
  ])
}

pub fn encode_request(
  request: UpsertLanguageVersionCacheWorkerConfigRequest,
) -> json.Json {
  json.object([
    #("refreshIntervalMs", json.int(request.refresh_interval_ms)),
    #("refreshStepDelayMs", json.int(request.refresh_step_delay_ms)),
    #("refreshStepJitterMs", json.int(request.refresh_step_jitter_ms)),
    #("defaultTimeoutMs", json.int(request.default_timeout_ms)),
  ])
}
