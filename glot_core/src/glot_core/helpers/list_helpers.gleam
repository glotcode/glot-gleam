import gleam/option.{type Option}

pub fn non_empty_list(l: List(a)) -> Option(List(a)) {
  case l {
    [] -> option.None
    _ -> option.Some(l)
  }
}
