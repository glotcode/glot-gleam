import gleam/int
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/pagination_model
import youid/uuid

pub type ApiLogSummary {
  ApiLogSummary(
    request_id: uuid.Uuid,
    created_at: Timestamp,
    action: String,
    duration_ns: Int,
    has_error: Bool,
  )
}

pub type ApiLogDetail {
  ApiLogDetail(request_id: uuid.Uuid, created_at: Timestamp, log: ApiLogEntry)
}

pub type ApiLogEntry {
  ApiLogEntry(
    created_at: Timestamp,
    action: String,
    body_bytes: Int,
    duration_ns: Int,
    ip: Option(String),
    user_agent: Option(String),
    info: Option(String),
    warnings: Option(String),
    debug: Option(String),
    error: Option(String),
    effects: Option(String),
  )
}

pub fn cursor(summary: ApiLogSummary) -> pagination_model.Cursor {
  let #(seconds, nanos) =
    timestamp.to_unix_seconds_and_nanoseconds(summary.created_at)

  pagination_model.from_string(
    int.to_string(seconds)
    <> "|"
    <> int.to_string(nanos)
    <> "|"
    <> uuid.to_string(summary.request_id),
  )
}

pub fn decode_cursor(
  cursor: pagination_model.Cursor,
) -> Result(#(Timestamp, uuid.Uuid), String) {
  case string.split(pagination_model.to_string(cursor), "|") {
    [seconds, nanos, request_id] -> {
      use parsed_seconds <- result.try(parse_int(seconds))
      use parsed_nanos <- result.try(parse_int(nanos))
      use parsed_request_id <- result.try(parse_uuid(request_id))

      Ok(#(
        timestamp.from_unix_seconds_and_nanoseconds(
          parsed_seconds,
          parsed_nanos,
        ),
        parsed_request_id,
      ))
    }
    _ -> Error("Invalid api log cursor")
  }
}

pub fn has_error(log: ApiLogSummary) -> Bool {
  log.has_error
}

fn parse_int(value: String) -> Result(Int, String) {
  int.parse(value)
  |> result.map_error(fn(_) { "Invalid api log cursor" })
}

fn parse_uuid(value: String) -> Result(uuid.Uuid, String) {
  uuid.from_string(value)
  |> result.map_error(fn(_) { "Invalid api log cursor" })
}
