import gleam/dict.{type Dict}
import gleam/json
import gleam/list
import gleam/option.{type Option}
import glot_core/email/email_address_model
import youid/uuid

pub type Fields =
  Dict(String, Value)

pub type Level {
  Info
  Warn
  Debug
}

pub fn level_to_string(level: Level) -> String {
  case level {
    Info -> "info"
    Warn -> "warn"
    Debug -> "debug"
  }
}

pub fn new() -> Fields {
  dict.new()
}

pub fn from_list(fields: List(#(String, Value))) -> Fields {
  dict.from_list(fields)
}

pub fn singleton(pair: #(String, Value)) -> Fields {
  dict.from_list([pair])
}

pub fn string(key: String, value: String) -> #(String, Value) {
  #(key, String(value))
}

pub fn string_list(key: String, values: List(String)) -> #(String, Value) {
  #(key, List(list.map(values, String)))
}

pub fn optional_string(key: String, value: Option(String)) -> #(String, Value) {
  case value {
    option.Some(v) -> #(key, String(v))
    option.None -> #(key, Null)
  }
}

pub fn bool(key: String, value: Bool) -> #(String, Value) {
  #(key, Bool(value))
}

pub fn int(key: String, value: Int) -> #(String, Value) {
  #(key, Int(value))
}

pub fn optional_int(key: String, value: Option(Int)) -> #(String, Value) {
  case value {
    option.Some(v) -> #(key, Int(v))
    option.None -> #(key, Null)
  }
}

pub fn object(key: String, items: List(#(String, Value))) -> #(String, Value) {
  #(key, Object(dict.from_list(items)))
}

pub fn uuid(key: String, value: uuid.Uuid) -> #(String, Value) {
  #(key, String(uuid.to_string(value)))
}

pub fn optional_uuid(
  key: String,
  value: Option(uuid.Uuid),
) -> #(String, Value) {
  case value {
    option.Some(v) -> #(key, String(uuid.to_string(v)))
    option.None -> #(key, Null)
  }
}

pub fn email(
  key: String,
  value: email_address_model.EmailAddress,
) -> #(String, Value) {
  #(key, String(email_address_model.to_string(value)))
}

pub fn encode_fields(fields: Fields) -> json.Json {
  fields
  |> dict.to_list
  |> list.map(fn(pair) {
    let #(key, value) = pair
    #(key, encode_value(value))
  })
  |> json.object
}

pub opaque type Value {
  String(String)
  Int(Int)
  Bool(Bool)
  Float(Float)
  Null
  Object(Dict(String, Value))
  List(List(Value))
}

pub fn encode_value(value: Value) -> json.Json {
  case value {
    String(v) -> json.string(v)
    Int(v) -> json.int(v)
    Bool(v) -> json.bool(v)
    Float(v) -> json.float(v)
    Null -> json.null()
    Object(v) ->
      v
      |> dict.to_list
      |> list.map(fn(pair) {
        let #(key, value) = pair
        #(key, encode_value(value))
      })
      |> json.object
    List(v) -> json.array(v, encode_value)
  }
}
