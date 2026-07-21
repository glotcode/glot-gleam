import gleam/time/timestamp.{type Timestamp}
import glot_core/helpers/timestamp_helpers

pub fn is_newer_than_saved_snippet(
  saved_at_ms: Int,
  updated_at: Timestamp,
) -> Bool {
  saved_at_ms > timestamp_helpers.to_microseconds(updated_at) / 1000
}
