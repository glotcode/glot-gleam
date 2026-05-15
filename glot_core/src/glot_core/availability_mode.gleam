import gleam/dynamic/decode
import gleam/json
import gleam/option

pub type AvailabilityMode {
  NormalMode
  ReadOnlyMode
  MaintenanceMode
}

pub fn to_string(mode: AvailabilityMode) -> String {
  case mode {
    NormalMode -> "normal"
    ReadOnlyMode -> "read_only"
    MaintenanceMode -> "maintenance"
  }
}

pub fn from_string(value: String) -> option.Option(AvailabilityMode) {
  case value {
    "normal" -> option.Some(NormalMode)
    "read_only" -> option.Some(ReadOnlyMode)
    "maintenance" -> option.Some(MaintenanceMode)
    _ -> option.None
  }
}

pub fn decoder() -> decode.Decoder(AvailabilityMode) {
  use value <- decode.then(decode.string)
  case from_string(value) {
    option.Some(mode) -> decode.success(mode)
    option.None -> decode.failure(NormalMode, "AvailabilityMode")
  }
}

pub fn encode(mode: AvailabilityMode) -> json.Json {
  json.string(to_string(mode))
}
