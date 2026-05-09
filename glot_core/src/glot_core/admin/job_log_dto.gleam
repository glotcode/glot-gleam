import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/effect_trace_dto
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import glot_core/job_log_model
import glot_core/pagination_model
import youid/uuid

pub type JobLogErrorFilter {
  AllJobLogs
  OnlyJobLogsWithErrors
}

pub type ListJobLogsRequest {
  ListJobLogsRequest(
    pagination: pagination_model.CursorPagination,
    request_id: option.Option(uuid.Uuid),
    job_id: option.Option(uuid.Uuid),
    error_filter: JobLogErrorFilter,
  )
}

pub type GetJobLogRequest {
  GetJobLogRequest(id: uuid.Uuid)
}

pub type JobLogResponse {
  JobLogResponse(
    id: uuid.Uuid,
    request_id: option.Option(uuid.Uuid),
    job_id: uuid.Uuid,
    job_type: String,
    attempt: Int,
    created_at: Timestamp,
    duration_ns: Int,
    has_error: Bool,
  )
}

pub type JobLogDetailResponse {
  JobLogDetailResponse(
    id: uuid.Uuid,
    request_id: option.Option(uuid.Uuid),
    job_id: uuid.Uuid,
    job_type: String,
    attempt: Int,
    created_at: Timestamp,
    duration_ns: Int,
    info: option.Option(String),
    warnings: option.Option(String),
    debug: option.Option(String),
    error: option.Option(String),
    effects: option.Option(effect_trace_dto.EffectTraceResponse),
  )
}

pub type ListJobLogsResponse {
  ListJobLogsResponse(page: pagination_model.CursorPage(JobLogResponse))
}

pub type GetJobLogResponse {
  GetJobLogResponse(log: JobLogDetailResponse)
}

pub fn list_request_decoder() -> decode.Decoder(ListJobLogsRequest) {
  decode.then(pagination_model.request_decoder(), fn(pagination) {
    use request_id <- decode.field(
      "requestId",
      decode.optional(uuid_helpers.decoder()),
    )
    use job_id <- decode.field("jobId", decode.optional(uuid_helpers.decoder()))
    use error_filter <- decode.field("errorFilter", error_filter_decoder())
    decode.success(ListJobLogsRequest(
      pagination: pagination,
      request_id: request_id,
      job_id: job_id,
      error_filter: error_filter,
    ))
  })
}

pub fn encode_list_request(request: ListJobLogsRequest) -> json.Json {
  json.object(
    list.append(pagination_model.encode_request_fields(request.pagination), [
      #("requestId", json.nullable(request.request_id, encode_uuid)),
      #("jobId", json.nullable(request.job_id, encode_uuid)),
      #("errorFilter", encode_error_filter(request.error_filter)),
    ]),
  )
}

pub fn get_request_decoder() -> decode.Decoder(GetJobLogRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(GetJobLogRequest(id: id))
}

pub fn encode_get_request(request: GetJobLogRequest) -> json.Json {
  json.object([#("id", encode_uuid(request.id))])
}

pub fn list_response_decoder() -> decode.Decoder(ListJobLogsResponse) {
  use page <- decode.field(
    "page",
    pagination_model.page_decoder("jobLogs", job_log_decoder()),
  )
  decode.success(ListJobLogsResponse(page: page))
}

pub fn encode_list_response(response: ListJobLogsResponse) -> json.Json {
  json.object([
    #("page", pagination_model.encode_page(response.page, "jobLogs", encode_job_log)),
  ])
}

pub fn get_response_decoder() -> decode.Decoder(GetJobLogResponse) {
  use log <- decode.field("log", job_log_detail_decoder())
  decode.success(GetJobLogResponse(log: log))
}

pub fn encode_get_response(response: GetJobLogResponse) -> json.Json {
  json.object([#("log", encode_job_log_detail(response.log))])
}

pub fn from_job_logs(
  page: pagination_model.CursorPage(job_log_model.JobLog),
) -> ListJobLogsResponse {
  ListJobLogsResponse(page: pagination_model.map_page(page, from_job_log))
}

pub fn from_job_log_detail(log: job_log_model.JobLog) -> GetJobLogResponse {
  GetJobLogResponse(log: JobLogDetailResponse(
    id: log.id,
    request_id: log.request_id,
    job_id: log.job_id,
    job_type: log.job_type,
    attempt: log.attempt,
    created_at: log.created_at,
    duration_ns: log.duration_ns,
    info: log.info,
    warnings: log.warnings,
    debug: log.debug,
    error: log.error,
    effects: effect_trace_dto.from_json_string(log.effects),
  ))
}

fn from_job_log(log: job_log_model.JobLog) -> JobLogResponse {
  JobLogResponse(
    id: log.id,
    request_id: log.request_id,
    job_id: log.job_id,
    job_type: log.job_type,
    attempt: log.attempt,
    created_at: log.created_at,
    duration_ns: log.duration_ns,
    has_error: job_log_model.has_error(log),
  )
}

fn job_log_decoder() -> decode.Decoder(JobLogResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use request_id <- decode.field(
    "requestId",
    decode.optional(uuid_helpers.decoder()),
  )
  use job_id <- decode.field("jobId", uuid_helpers.decoder())
  use job_type <- decode.field("jobType", decode.string)
  use attempt <- decode.field("attempt", decode.int)
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use duration_ns <- decode.field("durationNs", decode.int)
  use has_error <- decode.field("hasError", decode.bool)

  decode.success(JobLogResponse(
    id: id,
    request_id: request_id,
    job_id: job_id,
    job_type: job_type,
    attempt: attempt,
    created_at: created_at,
    duration_ns: duration_ns,
    has_error: has_error,
  ))
}

fn job_log_detail_decoder() -> decode.Decoder(JobLogDetailResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use request_id <- decode.field(
    "requestId",
    decode.optional(uuid_helpers.decoder()),
  )
  use job_id <- decode.field("jobId", uuid_helpers.decoder())
  use job_type <- decode.field("jobType", decode.string)
  use attempt <- decode.field("attempt", decode.int)
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use duration_ns <- decode.field("durationNs", decode.int)
  use info <- decode.field("info", decode.optional(decode.string))
  use warnings <- decode.field("warnings", decode.optional(decode.string))
  use debug <- decode.field("debug", decode.optional(decode.string))
  use error <- decode.field("error", decode.optional(decode.string))
  use effects <- decode.field("effects", decode.optional(effect_trace_dto.decoder()))

  decode.success(JobLogDetailResponse(
    id: id,
    request_id: request_id,
    job_id: job_id,
    job_type: job_type,
    attempt: attempt,
    created_at: created_at,
    duration_ns: duration_ns,
    info: info,
    warnings: warnings,
    debug: debug,
    error: error,
    effects: effects,
  ))
}

fn encode_job_log(log: JobLogResponse) -> json.Json {
  json.object([
    #("id", encode_uuid(log.id)),
    #("requestId", json.nullable(log.request_id, encode_uuid)),
    #("jobId", encode_uuid(log.job_id)),
    #("jobType", json.string(log.job_type)),
    #("attempt", json.int(log.attempt)),
    #("createdAt", timestamp_helpers.encode(log.created_at)),
    #("durationNs", json.int(log.duration_ns)),
    #("hasError", json.bool(log.has_error)),
  ])
}

fn encode_job_log_detail(log: JobLogDetailResponse) -> json.Json {
  json.object([
    #("id", encode_uuid(log.id)),
    #("requestId", json.nullable(log.request_id, encode_uuid)),
    #("jobId", encode_uuid(log.job_id)),
    #("jobType", json.string(log.job_type)),
    #("attempt", json.int(log.attempt)),
    #("createdAt", timestamp_helpers.encode(log.created_at)),
    #("durationNs", json.int(log.duration_ns)),
    #("info", json.nullable(log.info, json.string)),
    #("warnings", json.nullable(log.warnings, json.string)),
    #("debug", json.nullable(log.debug, json.string)),
    #("error", json.nullable(log.error, json.string)),
    #("effects", json.nullable(log.effects, effect_trace_dto.encode)),
  ])
}

fn error_filter_decoder() -> decode.Decoder(JobLogErrorFilter) {
  decode.then(decode.string, fn(value) {
    case value {
      "all" -> decode.success(AllJobLogs)
      "errors_only" -> decode.success(OnlyJobLogsWithErrors)
      _ -> decode.failure(AllJobLogs, "JobLogErrorFilter")
    }
  })
}

fn encode_error_filter(filter: JobLogErrorFilter) -> json.Json {
  json.string(case filter {
    AllJobLogs -> "all"
    OnlyJobLogsWithErrors -> "errors_only"
  })
}

fn encode_uuid(value: uuid.Uuid) -> json.Json {
  uuid.to_string(value)
  |> json.string
}
