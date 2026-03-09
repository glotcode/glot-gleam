import gleam/dict.{type Dict}
import gleam/json
import gleam/list

pub type Fields =
  Dict(String, Value)

pub fn new() -> Fields {
  dict.new()
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

pub type Value {
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
