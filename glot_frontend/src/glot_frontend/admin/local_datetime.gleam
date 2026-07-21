import gleam/option
import gleam/time/timestamp.{type Timestamp}

pub type LocalDateTime {
  LocalDateTime(date: String, time: String)
}

pub type ParseResult =
  option.Option(Timestamp)
