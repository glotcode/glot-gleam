import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub fn non_empty_dict(d: Dict(k, v)) -> Option(Dict(k, v)) {
  case dict.is_empty(d) {
    True -> option.None
    False -> option.Some(d)
  }
}
