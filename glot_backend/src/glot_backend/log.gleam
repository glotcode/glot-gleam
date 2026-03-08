import gleam/dict.{type Dict}

pub type Value {
  String(String)
  Int(Int)
  Bool(Bool)
  Float(Float)
  Null
  Object(Dict(String, Value))
  List(List(Value))
}
