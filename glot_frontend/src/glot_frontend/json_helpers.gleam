import gleam/option

pub fn optional_pretty_print_json_or_none(
  value: option.Option(String),
) -> String {
  case value {
    option.Some(text) -> pretty_print_json_or_raw(text)
    option.None -> "None"
  }
}

@external(javascript, "./json_helpers_ffi.mjs", "prettyPrintJsonOrRaw")
fn pretty_print_json_or_raw(value: String) -> String
