import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/result
import gleam/string
import glot_backend/app_config/model/entry.{type AppConfigEntry}

pub fn int(namespace: String, entry: AppConfigEntry) -> Result(Int, String) {
  json(namespace, entry, decode.int)
}

pub fn optional_int(
  namespace: String,
  entry: AppConfigEntry,
) -> Result(Option(Int), String) {
  json(namespace, entry, decode.optional(decode.int))
}

pub fn string(
  namespace: String,
  entry: AppConfigEntry,
) -> Result(String, String) {
  json(namespace, entry, decode.string)
}

pub fn optional_string(
  namespace: String,
  entry: AppConfigEntry,
) -> Result(Option(String), String) {
  json(namespace, entry, decode.optional(decode.string))
}

pub fn bool(namespace: String, entry: AppConfigEntry) -> Result(Bool, String) {
  json(namespace, entry, decode.bool)
}

pub fn json(
  namespace: String,
  entry: AppConfigEntry,
  decoder: decode.Decoder(value),
) -> Result(value, String) {
  json.parse(entry.value, decoder)
  |> result.map_error(fn(error) {
    "Failed to decode "
    <> namespace
    <> " app_config for "
    <> entry.key
    <> ": "
    <> string.inspect(error)
  })
}
