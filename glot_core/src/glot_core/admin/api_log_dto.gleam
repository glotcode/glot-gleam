import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/api_log_model
import glot_core/effect_trace_dto
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import glot_core/pagination_model
import youid/uuid

pub type ApiLogErrorFilter {
  AllApiLogs
  OnlyApiLogsWithErrors
}

pub type ListApiLogsRequest {
  ListApiLogsRequest(
    pagination: pagination_model.CursorPagination,
    request_id: option.Option(uuid.Uuid),
    error_filter: ApiLogErrorFilter,
  )
}

pub type GetApiLogRequest {
  GetApiLogRequest(request_id: uuid.Uuid)
}

pub type ApiLogSummaryResponse {
  ApiLogSummaryResponse(
    request_id: uuid.Uuid,
    created_at: Timestamp,
    action: String,
    duration_ns: Int,
    has_error: Bool,
  )
}

pub type ApiLogEntryResponse {
  ApiLogEntryResponse(
    created_at: Timestamp,
    action: String,
    body_bytes: Int,
    duration_ns: Int,
    ip: option.Option(String),
    user_agent: option.Option(String),
    info: option.Option(String),
    warnings: option.Option(String),
    debug: option.Option(String),
    error: option.Option(String),
    effects: option.Option(effect_trace_dto.EffectTraceResponse),
  )
}

pub type ApiLogDetailResponse {
  ApiLogDetailResponse(
    request_id: uuid.Uuid,
    created_at: Timestamp,
    log: ApiLogEntryResponse,
  )
}

pub type ListApiLogsResponse {
  ListApiLogsResponse(page: pagination_model.CursorPage(ApiLogSummaryResponse))
}

pub type GetApiLogResponse {
  GetApiLogResponse(log: ApiLogDetailResponse)
}

pub fn list_request_decoder() -> decode.Decoder(ListApiLogsRequest) {
  decode.then(pagination_model.request_decoder(), fn(pagination) {
    use request_id <- decode.field(
      "requestId",
      decode.optional(uuid_helpers.decoder()),
    )
    use error_filter <- decode.field("errorFilter", error_filter_decoder())
    decode.success(ListApiLogsRequest(
      pagination: pagination,
      request_id: request_id,
      error_filter: error_filter,
    ))
  })
}

pub fn encode_list_request(request: ListApiLogsRequest) -> json.Json {
  json.object(
    list.append(pagination_model.encode_request_fields(request.pagination), [
      #("requestId", json.nullable(request.request_id, encode_uuid)),
      #("errorFilter", encode_error_filter(request.error_filter)),
    ]),
  )
}

pub fn get_request_decoder() -> decode.Decoder(GetApiLogRequest) {
  use request_id <- decode.field("requestId", uuid_helpers.decoder())
  decode.success(GetApiLogRequest(request_id: request_id))
}

pub fn encode_get_request(request: GetApiLogRequest) -> json.Json {
  json.object([#("requestId", encode_uuid(request.request_id))])
}

pub fn list_response_decoder() -> decode.Decoder(ListApiLogsResponse) {
  use page <- decode.field(
    "page",
    pagination_model.page_decoder("apiLogs", api_log_summary_decoder()),
  )
  decode.success(ListApiLogsResponse(page: page))
}

pub fn encode_list_response(response: ListApiLogsResponse) -> json.Json {
  json.object([
    #(
      "page",
      pagination_model.encode_page(
        response.page,
        "apiLogs",
        encode_api_log_summary,
      ),
    ),
  ])
}

pub fn get_response_decoder() -> decode.Decoder(GetApiLogResponse) {
  use log <- decode.field("log", api_log_detail_decoder())
  decode.success(GetApiLogResponse(log: log))
}

pub fn encode_get_response(response: GetApiLogResponse) -> json.Json {
  json.object([#("log", encode_api_log_detail(response.log))])
}

pub fn from_api_logs(
  page: pagination_model.CursorPage(api_log_model.ApiLogSummary),
) -> ListApiLogsResponse {
  ListApiLogsResponse(page: pagination_model.map_page(page, from_api_log_summary))
}

pub fn from_api_log_detail(log: api_log_model.ApiLogDetail) -> GetApiLogResponse {
  GetApiLogResponse(log: ApiLogDetailResponse(
    request_id: log.request_id,
    created_at: log.created_at,
    log: from_api_log_entry(log.log),
  ))
}

fn from_api_log_summary(log: api_log_model.ApiLogSummary) -> ApiLogSummaryResponse {
  ApiLogSummaryResponse(
    request_id: log.request_id,
    created_at: log.created_at,
    action: log.action,
    duration_ns: log.duration_ns,
    has_error: api_log_model.has_error(log),
  )
}

fn from_api_log_entry(log: api_log_model.ApiLogEntry) -> ApiLogEntryResponse {
  ApiLogEntryResponse(
    created_at: log.created_at,
    action: log.action,
    body_bytes: log.body_bytes,
    duration_ns: log.duration_ns,
    ip: log.ip,
    user_agent: log.user_agent,
    info: log.info,
    warnings: log.warnings,
    debug: log.debug,
    error: log.error,
    effects: effect_trace_dto.from_json_string(log.effects),
  )
}

fn api_log_summary_decoder() -> decode.Decoder(ApiLogSummaryResponse) {
  use request_id <- decode.field("requestId", uuid_helpers.decoder())
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use action <- decode.field("action", decode.string)
  use duration_ns <- decode.field("durationNs", decode.int)
  use has_error <- decode.field("hasError", decode.bool)

  decode.success(ApiLogSummaryResponse(
    request_id: request_id,
    created_at: created_at,
    action: action,
    duration_ns: duration_ns,
    has_error: has_error,
  ))
}

fn api_log_detail_decoder() -> decode.Decoder(ApiLogDetailResponse) {
  use request_id <- decode.field("requestId", uuid_helpers.decoder())
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use log <- decode.field("log", api_log_entry_decoder())

  decode.success(ApiLogDetailResponse(
    request_id: request_id,
    created_at: created_at,
    log: log,
  ))
}

fn api_log_entry_decoder() -> decode.Decoder(ApiLogEntryResponse) {
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use action <- decode.field("action", decode.string)
  use body_bytes <- decode.field("bodyBytes", decode.int)
  use duration_ns <- decode.field("durationNs", decode.int)
  use ip <- decode.field("ip", decode.optional(decode.string))
  use user_agent <- decode.field("userAgent", decode.optional(decode.string))
  use info <- decode.field("info", decode.optional(decode.string))
  use warnings <- decode.field("warnings", decode.optional(decode.string))
  use debug <- decode.field("debug", decode.optional(decode.string))
  use error <- decode.field("error", decode.optional(decode.string))
  use effects <- decode.field("effects", decode.optional(effect_trace_dto.decoder()))

  decode.success(ApiLogEntryResponse(
    created_at: created_at,
    action: action,
    body_bytes: body_bytes,
    duration_ns: duration_ns,
    ip: ip,
    user_agent: user_agent,
    info: info,
    warnings: warnings,
    debug: debug,
    error: error,
    effects: effects,
  ))
}

fn encode_api_log_summary(log: ApiLogSummaryResponse) -> json.Json {
  json.object([
    #("requestId", encode_uuid(log.request_id)),
    #("createdAt", timestamp_helpers.encode(log.created_at)),
    #("action", json.string(log.action)),
    #("durationNs", json.int(log.duration_ns)),
    #("hasError", json.bool(log.has_error)),
  ])
}

fn encode_api_log_detail(log: ApiLogDetailResponse) -> json.Json {
  json.object([
    #("requestId", encode_uuid(log.request_id)),
    #("createdAt", timestamp_helpers.encode(log.created_at)),
    #("log", encode_api_log_entry(log.log)),
  ])
}

fn encode_api_log_entry(log: ApiLogEntryResponse) -> json.Json {
  json.object([
    #("createdAt", timestamp_helpers.encode(log.created_at)),
    #("action", json.string(log.action)),
    #("bodyBytes", json.int(log.body_bytes)),
    #("durationNs", json.int(log.duration_ns)),
    #("ip", json.nullable(log.ip, json.string)),
    #("userAgent", json.nullable(log.user_agent, json.string)),
    #("info", json.nullable(log.info, json.string)),
    #("warnings", json.nullable(log.warnings, json.string)),
    #("debug", json.nullable(log.debug, json.string)),
    #("error", json.nullable(log.error, json.string)),
    #("effects", json.nullable(log.effects, effect_trace_dto.encode)),
  ])
}

fn error_filter_decoder() -> decode.Decoder(ApiLogErrorFilter) {
  decode.then(decode.string, fn(value) {
    case value {
      "all" -> decode.success(AllApiLogs)
      "errors_only" -> decode.success(OnlyApiLogsWithErrors)
      _ -> decode.failure(AllApiLogs, "ApiLogErrorFilter")
    }
  })
}

fn encode_error_filter(filter: ApiLogErrorFilter) -> json.Json {
  json.string(case filter {
    AllApiLogs -> "all"
    OnlyApiLogsWithErrors -> "errors_only"
  })
}

fn encode_uuid(value: uuid.Uuid) -> json.Json {
  uuid.to_string(value)
  |> json.string
}
