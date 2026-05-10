import gleam/int
import gleam/option.{type Option}
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/language.{type Language}
import glot_core/pagination_model
import youid/uuid.{type Uuid}

pub type RunOutcome {
  RunSucceeded
  RunFailed
}

pub fn run_outcome_to_string(outcome: RunOutcome) -> String {
  case outcome {
    RunSucceeded -> "succeeded"
    RunFailed -> "failed"
  }
}

pub fn run_outcome_from_string(value: String) -> Option(RunOutcome) {
  case value {
    "succeeded" -> option.Some(RunSucceeded)
    "failed" -> option.Some(RunFailed)
    _ -> option.None
  }
}

pub type RunLog {
  RunLog(
    id: Uuid,
    request_id: Uuid,
    created_at: Timestamp,
    session_id: Option(Uuid),
    user_id: Option(Uuid),
    language: Language,
    outcome: RunOutcome,
    duration_ns: Option(Int),
    failure_message: Option(String),
  )
}

pub fn cursor(log: RunLog) -> pagination_model.Cursor {
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
) -> Result(#(Timestamp, uuid.Uuid), String) {
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
    _ -> Error("Invalid run log cursor")
  }
}

pub fn has_failure(log: RunLog) -> Bool {
  case log.outcome {
    RunSucceeded -> False
    RunFailed -> True
  }
}

fn parse_int(value: String) -> Result(Int, String) {
  int.parse(value)
  |> result.map_error(fn(_) { "Invalid run log cursor" })
}

fn parse_uuid(value: String) -> Result(uuid.Uuid, String) {
  uuid.from_string(value)
  |> result.map_error(fn(_) { "Invalid run log cursor" })
}
