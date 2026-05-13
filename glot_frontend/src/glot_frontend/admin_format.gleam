import gleam/int
import gleam/option
import gleam/result
import gleam/time/calendar
import gleam/time/timestamp
import youid/uuid

pub fn format_timestamp(value: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}

pub fn optional_text(value: option.Option(String)) -> String {
  case value {
    option.Some(text) -> text
    option.None -> "None"
  }
}

pub fn optional_uuid(value: option.Option(uuid.Uuid)) -> String {
  case value {
    option.Some(id) -> uuid.to_string(id)
    option.None -> "None"
  }
}

pub fn optional_timestamp(value: option.Option(timestamp.Timestamp)) -> String {
  case value {
    option.Some(timestamp) -> format_timestamp(timestamp)
    option.None -> "None"
  }
}

pub fn parse_positive_int(value: String, label: String) -> Result(Int, String) {
  use parsed <- result.try(
    int.parse(value)
    |> result.map_error(fn(_) { label <> " must be a whole number." }),
  )

  case parsed > 0 {
    True -> Ok(parsed)
    False -> Error(label <> " must be greater than zero.")
  }
}

pub fn parse_positive_int_with_error(
  value: String,
  error_message: String,
) -> Result(Int, String) {
  use parsed <- result.try(
    int.parse(value)
    |> result.map_error(fn(_) { error_message }),
  )

  case parsed > 0 {
    True -> Ok(parsed)
    False -> Error(error_message)
  }
}
