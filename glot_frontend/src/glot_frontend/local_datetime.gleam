import gleam/time/timestamp.{type Timestamp}

pub fn timestamp_to_local_date_input(value: Timestamp) -> String {
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(value)
  timestamp_to_local_date_input_ffi(seconds, nanoseconds)
}

pub fn timestamp_to_local_time_input(value: Timestamp) -> String {
  let #(seconds, nanoseconds) = timestamp.to_unix_seconds_and_nanoseconds(value)
  timestamp_to_local_time_input_ffi(seconds, nanoseconds)
}

pub fn local_date_time_to_unix_milliseconds(date: String, time: String) -> Int {
  local_date_time_to_unix_milliseconds_ffi(date, time)
}

@external(javascript, "./local_datetime_ffi.mjs", "timestampToLocalDateInput")
fn timestamp_to_local_date_input_ffi(seconds: Int, nanoseconds: Int) -> String

@external(javascript, "./local_datetime_ffi.mjs", "timestampToLocalTimeInput")
fn timestamp_to_local_time_input_ffi(seconds: Int, nanoseconds: Int) -> String

@external(javascript, "./local_datetime_ffi.mjs", "localDateTimeToUnixMilliseconds")
fn local_date_time_to_unix_milliseconds_ffi(date: String, time: String) -> Int
