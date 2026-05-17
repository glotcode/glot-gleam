import gleam/int
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/pagination_model
import glot_core/validation_error
import youid/uuid

pub type JobLog {
  JobLog(
    id: uuid.Uuid,
    request_id: Option(uuid.Uuid),
    job_id: uuid.Uuid,
    job_type: String,
    attempt: Int,
    created_at: Timestamp,
    duration_ns: Int,
    info: Option(String),
    warnings: Option(String),
    debug: Option(String),
    error: Option(String),
    effects: Option(String),
  )
}

pub fn cursor(log: JobLog) -> pagination_model.Cursor {
  let #(seconds, nanos) =
    timestamp.to_unix_seconds_and_nanoseconds(log.created_at)

  pagination_model.from_string(
    int.to_string(seconds)
    <> "|"
    <> int.to_string(nanos)
    <> "|"
    <> uuid.to_string(log.id),
  )
}

pub fn decode_cursor(
  cursor: pagination_model.Cursor,
) -> Result(#(Timestamp, uuid.Uuid), validation_error.ValidationError) {
  case string.split(pagination_model.to_string(cursor), "|") {
    [seconds, nanos, id] -> {
      use parsed_seconds <- result.try(parse_int(seconds))
      use parsed_nanos <- result.try(parse_int(nanos))
      use parsed_id <- result.try(parse_uuid(id))

      Ok(#(
        timestamp.from_unix_seconds_and_nanoseconds(
          parsed_seconds,
          parsed_nanos,
        ),
        parsed_id,
      ))
    }
    _ -> Error(validation_error.InvalidCursor(validation_error.JobLogCursor))
  }
}

pub fn has_error(log: JobLog) -> Bool {
  case log.error {
    option.Some(_) -> True
    option.None -> False
  }
}

fn parse_int(value: String) -> Result(Int, validation_error.ValidationError) {
  int.parse(value)
  |> result.map_error(fn(_) {
    validation_error.InvalidCursor(validation_error.JobLogCursor)
  })
}

fn parse_uuid(
  value: String,
) -> Result(uuid.Uuid, validation_error.ValidationError) {
  uuid.from_string(value)
  |> result.map_error(fn(_) {
    validation_error.InvalidCursor(validation_error.JobLogCursor)
  })
}
