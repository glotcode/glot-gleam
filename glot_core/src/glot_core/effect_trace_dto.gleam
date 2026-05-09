import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option

pub type EffectTraceResponse {
  EffectTraceResponse(effects: List(EffectMeasurementResponse))
}

pub type EffectMeasurementResponse {
  EffectMeasurementResponse(
    category: String,
    name: String,
    duration_ns: Int,
    rolled_back: option.Option(Bool),
    effects: List(EffectMeasurementResponse),
  )
}

pub fn decoder() -> decode.Decoder(EffectTraceResponse) {
  use effects <- decode.field(
    "effects",
    decode.list(effect_measurement_decoder()),
  )
  decode.success(EffectTraceResponse(effects: effects))
}

pub fn encode(effect_trace: EffectTraceResponse) -> json.Json {
  let EffectTraceResponse(effects:) = effect_trace

  json.object([
    #("effects", json.array(effects, encode_effect_measurement)),
  ])
}

pub fn from_json_string(
  value: option.Option(String),
) -> option.Option(EffectTraceResponse) {
  case value {
    option.Some(value) ->
      case json.parse(value, decoder()) {
        Ok(effect_trace) -> option.Some(effect_trace)
        Error(_) -> option.None
      }
    option.None -> option.None
  }
}

fn effect_measurement_decoder() -> decode.Decoder(EffectMeasurementResponse) {
  use category <- decode.field("category", decode.string)
  use name <- decode.field("name", decode.string)
  use duration_ns <- decode.field("duration_ns", decode.int)
  use rolled_back <- decode.optional_field(
    "rolled_back",
    option.None,
    decode.optional(decode.bool),
  )
  use effects <- decode.optional_field(
    "effects",
    [],
    decode.list(effect_measurement_decoder()),
  )

  decode.success(EffectMeasurementResponse(
    category: category,
    name: name,
    duration_ns: duration_ns,
    rolled_back: rolled_back,
    effects: effects,
  ))
}

fn encode_effect_measurement(
  effect_measurement: EffectMeasurementResponse,
) -> json.Json {
  json.object([
    #("category", json.string(effect_measurement.category)),
    #("name", json.string(effect_measurement.name)),
    #("duration_ns", json.int(effect_measurement.duration_ns)),
    #("rolled_back", json.nullable(effect_measurement.rolled_back, json.bool)),
    #(
      "effects",
      json.array(effect_measurement.effects, encode_effect_measurement),
    ),
  ])
}
