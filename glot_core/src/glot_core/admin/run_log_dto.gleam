import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import glot_core/language
import glot_core/pagination_model
import glot_core/run_log_model
import youid/uuid

pub type RunLogOutcomeFilter {
  AllRunLogs
  OnlySuccessfulRunLogs
  OnlyFailedRunLogs
}

pub type ListRunLogsRequest {
  ListRunLogsRequest(
    pagination: pagination_model.CursorPagination,
    request_id: option.Option(uuid.Uuid),
    session_id: option.Option(uuid.Uuid),
    user_id: option.Option(uuid.Uuid),
    language: option.Option(language.Language),
    outcome_filter: RunLogOutcomeFilter,
  )
}

pub type GetRunLogRequest {
  GetRunLogRequest(id: uuid.Uuid)
}

pub type RunLogResponse {
  RunLogResponse(
    id: uuid.Uuid,
    request_id: uuid.Uuid,
    created_at: Timestamp,
    session_id: option.Option(uuid.Uuid),
    user_id: option.Option(uuid.Uuid),
    language: language.Language,
    outcome: run_log_model.RunOutcome,
    duration_ns: option.Option(Int),
    has_failure: Bool,
  )
}

pub type RunLogDetailResponse {
  RunLogDetailResponse(
    id: uuid.Uuid,
    request_id: uuid.Uuid,
    created_at: Timestamp,
    session_id: option.Option(uuid.Uuid),
    user_id: option.Option(uuid.Uuid),
    language: language.Language,
    outcome: run_log_model.RunOutcome,
    duration_ns: option.Option(Int),
    failure_message: option.Option(String),
  )
}

pub type ListRunLogsResponse {
  ListRunLogsResponse(page: pagination_model.CursorPage(RunLogResponse))
}

pub type GetRunLogResponse {
  GetRunLogResponse(log: RunLogDetailResponse)
}

pub fn list_request_decoder() -> decode.Decoder(ListRunLogsRequest) {
  decode.then(pagination_model.request_decoder(), fn(pagination) {
    use request_id <- decode.field(
      "requestId",
      decode.optional(uuid_helpers.decoder()),
    )
    use session_id <- decode.field(
      "sessionId",
      decode.optional(uuid_helpers.decoder()),
    )
    use user_id <- decode.field("userId", decode.optional(uuid_helpers.decoder()))
    use maybe_language <- decode.field(
      "language",
      decode.optional(language.decoder()),
    )
    use outcome_filter <- decode.field("outcomeFilter", outcome_filter_decoder())
    decode.success(ListRunLogsRequest(
      pagination: pagination,
      request_id: request_id,
      session_id: session_id,
      user_id: user_id,
      language: maybe_language,
      outcome_filter: outcome_filter,
    ))
  })
}

pub fn encode_list_request(request: ListRunLogsRequest) -> json.Json {
  json.object(
    list.append(pagination_model.encode_request_fields(request.pagination), [
      #("requestId", json.nullable(request.request_id, encode_uuid)),
      #("sessionId", json.nullable(request.session_id, encode_uuid)),
      #("userId", json.nullable(request.user_id, encode_uuid)),
      #("language", json.nullable(request.language, language.encode)),
      #("outcomeFilter", encode_outcome_filter(request.outcome_filter)),
    ]),
  )
}

pub fn get_request_decoder() -> decode.Decoder(GetRunLogRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(GetRunLogRequest(id: id))
}

pub fn encode_get_request(request: GetRunLogRequest) -> json.Json {
  json.object([#("id", encode_uuid(request.id))])
}

pub fn list_response_decoder() -> decode.Decoder(ListRunLogsResponse) {
  use page <- decode.field(
    "page",
    pagination_model.page_decoder("runLogs", run_log_decoder()),
  )
  decode.success(ListRunLogsResponse(page: page))
}

pub fn encode_list_response(response: ListRunLogsResponse) -> json.Json {
  json.object([
    #(
      "page",
      pagination_model.encode_page(response.page, "runLogs", encode_run_log),
    ),
  ])
}

pub fn get_response_decoder() -> decode.Decoder(GetRunLogResponse) {
  use log <- decode.field("log", run_log_detail_decoder())
  decode.success(GetRunLogResponse(log: log))
}

pub fn encode_get_response(response: GetRunLogResponse) -> json.Json {
  json.object([#("log", encode_run_log_detail(response.log))])
}

pub fn from_run_logs(
  page: pagination_model.CursorPage(run_log_model.RunLog),
) -> ListRunLogsResponse {
  ListRunLogsResponse(page: pagination_model.map_page(page, from_run_log))
}

pub fn from_run_log_detail(log: run_log_model.RunLog) -> GetRunLogResponse {
  GetRunLogResponse(log: RunLogDetailResponse(
    id: log.id,
    request_id: log.request_id,
    created_at: log.created_at,
    session_id: log.session_id,
    user_id: log.user_id,
    language: log.language,
    outcome: log.outcome,
    duration_ns: log.duration_ns,
    failure_message: log.failure_message,
  ))
}

fn from_run_log(log: run_log_model.RunLog) -> RunLogResponse {
  RunLogResponse(
    id: log.id,
    request_id: log.request_id,
    created_at: log.created_at,
    session_id: log.session_id,
    user_id: log.user_id,
    language: log.language,
    outcome: log.outcome,
    duration_ns: log.duration_ns,
    has_failure: run_log_model.has_failure(log),
  )
}

fn run_log_decoder() -> decode.Decoder(RunLogResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use request_id <- decode.field("requestId", uuid_helpers.decoder())
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use session_id <- decode.field(
    "sessionId",
    decode.optional(uuid_helpers.decoder()),
  )
  use user_id <- decode.field("userId", decode.optional(uuid_helpers.decoder()))
  use language <- decode.field("language", language.decoder())
  use outcome <- decode.field("outcome", run_outcome_decoder())
  use duration_ns <- decode.field("durationNs", decode.optional(decode.int))
  use has_failure <- decode.field("hasFailure", decode.bool)

  decode.success(RunLogResponse(
    id: id,
    request_id: request_id,
    created_at: created_at,
    session_id: session_id,
    user_id: user_id,
    language: language,
    outcome: outcome,
    duration_ns: duration_ns,
    has_failure: has_failure,
  ))
}

fn run_log_detail_decoder() -> decode.Decoder(RunLogDetailResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use request_id <- decode.field("requestId", uuid_helpers.decoder())
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use session_id <- decode.field(
    "sessionId",
    decode.optional(uuid_helpers.decoder()),
  )
  use user_id <- decode.field("userId", decode.optional(uuid_helpers.decoder()))
  use language <- decode.field("language", language.decoder())
  use outcome <- decode.field("outcome", run_outcome_decoder())
  use duration_ns <- decode.field("durationNs", decode.optional(decode.int))
  use failure_message <- decode.field(
    "failureMessage",
    decode.optional(decode.string),
  )

  decode.success(RunLogDetailResponse(
    id: id,
    request_id: request_id,
    created_at: created_at,
    session_id: session_id,
    user_id: user_id,
    language: language,
    outcome: outcome,
    duration_ns: duration_ns,
    failure_message: failure_message,
  ))
}

fn encode_run_log(log: RunLogResponse) -> json.Json {
  json.object([
    #("id", encode_uuid(log.id)),
    #("requestId", encode_uuid(log.request_id)),
    #("createdAt", timestamp_helpers.encode(log.created_at)),
    #("sessionId", json.nullable(log.session_id, encode_uuid)),
    #("userId", json.nullable(log.user_id, encode_uuid)),
    #("language", language.encode(log.language)),
    #("outcome", encode_run_outcome(log.outcome)),
    #("durationNs", json.nullable(log.duration_ns, json.int)),
    #("hasFailure", json.bool(log.has_failure)),
  ])
}

fn encode_run_log_detail(log: RunLogDetailResponse) -> json.Json {
  json.object([
    #("id", encode_uuid(log.id)),
    #("requestId", encode_uuid(log.request_id)),
    #("createdAt", timestamp_helpers.encode(log.created_at)),
    #("sessionId", json.nullable(log.session_id, encode_uuid)),
    #("userId", json.nullable(log.user_id, encode_uuid)),
    #("language", language.encode(log.language)),
    #("outcome", encode_run_outcome(log.outcome)),
    #("durationNs", json.nullable(log.duration_ns, json.int)),
    #("failureMessage", json.nullable(log.failure_message, json.string)),
  ])
}

fn outcome_filter_decoder() -> decode.Decoder(RunLogOutcomeFilter) {
  decode.then(decode.string, fn(value) {
    case value {
      "all" -> decode.success(AllRunLogs)
      "succeeded" -> decode.success(OnlySuccessfulRunLogs)
      "failed" -> decode.success(OnlyFailedRunLogs)
      _ -> decode.failure(AllRunLogs, "Invalid run log outcome filter")
    }
  })
}

fn encode_outcome_filter(filter: RunLogOutcomeFilter) -> json.Json {
  json.string(case filter {
    AllRunLogs -> "all"
    OnlySuccessfulRunLogs -> "succeeded"
    OnlyFailedRunLogs -> "failed"
  })
}

fn run_outcome_decoder() -> decode.Decoder(run_log_model.RunOutcome) {
  decode.then(decode.string, fn(value) {
    case run_log_model.run_outcome_from_string(value) {
      option.Some(outcome) -> decode.success(outcome)
      option.None -> decode.failure(
        run_log_model.RunSucceeded,
        "Invalid run log outcome",
      )
    }
  })
}

fn encode_run_outcome(outcome: run_log_model.RunOutcome) -> json.Json {
  json.string(run_log_model.run_outcome_to_string(outcome))
}

fn encode_uuid(id: uuid.Uuid) -> json.Json {
  json.string(uuid.to_string(id))
}
