import gleam/int
import gleam/string

pub fn truncate_stem_middle(stem: String, max_length: Int) -> String {
  case string.length(stem) > max_length {
    False -> stem
    True ->
      case max_length <= 4 {
        True -> string.slice(stem, 0, max_length)
        False -> {
          let visible_length = max_length - 3
          let assert Ok(suffix_length) = int.divide(visible_length, by: 2)
          let prefix_length = visible_length - suffix_length

          string.slice(stem, 0, prefix_length)
          <> "..."
          <> string.slice(stem, -suffix_length, string.length(stem))
        }
      }
  }
}
