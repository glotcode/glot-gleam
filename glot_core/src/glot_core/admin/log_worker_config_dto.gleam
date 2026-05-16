import gleam/dynamic/decode
import gleam/json

pub type LogWorkerConfigResponse {
  LogWorkerConfigResponse(
    flush_interval_ms: Int,
    max_batch_size: Int,
    max_buffer_size: Int,
  )
}

pub type UpsertLogWorkerConfigRequest {
  UpsertLogWorkerConfigRequest(
    flush_interval_ms: Int,
    max_batch_size: Int,
    max_buffer_size: Int,
  )
}

pub fn response_decoder() -> decode.Decoder(LogWorkerConfigResponse) {
  use flush_interval_ms <- decode.field("flushIntervalMs", decode.int)
  use max_batch_size <- decode.field("maxBatchSize", decode.int)
  use max_buffer_size <- decode.field("maxBufferSize", decode.int)
  decode.success(LogWorkerConfigResponse(
    flush_interval_ms: flush_interval_ms,
    max_batch_size: max_batch_size,
    max_buffer_size: max_buffer_size,
  ))
}

pub fn decoder() -> decode.Decoder(UpsertLogWorkerConfigRequest) {
  use flush_interval_ms <- decode.field("flushIntervalMs", decode.int)
  use max_batch_size <- decode.field("maxBatchSize", decode.int)
  use max_buffer_size <- decode.field("maxBufferSize", decode.int)
  decode.success(UpsertLogWorkerConfigRequest(
    flush_interval_ms: flush_interval_ms,
    max_batch_size: max_batch_size,
    max_buffer_size: max_buffer_size,
  ))
}

pub fn encode_response(response: LogWorkerConfigResponse) -> json.Json {
  json.object([
    #("flushIntervalMs", json.int(response.flush_interval_ms)),
    #("maxBatchSize", json.int(response.max_batch_size)),
    #("maxBufferSize", json.int(response.max_buffer_size)),
  ])
}

pub fn encode_request(request: UpsertLogWorkerConfigRequest) -> json.Json {
  json.object([
    #("flushIntervalMs", json.int(request.flush_interval_ms)),
    #("maxBatchSize", json.int(request.max_batch_size)),
    #("maxBufferSize", json.int(request.max_buffer_size)),
  ])
}
