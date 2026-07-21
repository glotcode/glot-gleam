import gleam/list
import gleam/option
import gleam/string
import glot_core/snippet/snippet_model
import glot_frontend/ui/string_helpers

pub fn select_main_name(
  files: List(snippet_model.File),
  default_name: String,
) -> String {
  find_name(files, default_name) |> option.unwrap(first_name(files))
}

pub fn find_name(
  files: List(snippet_model.File),
  target: String,
) -> option.Option(String) {
  case files {
    [] -> option.None
    [snippet_model.File(name:, ..), ..rest] ->
      case name == target {
        True -> option.Some(name)
        False -> find_name(rest, target)
      }
  }
}

pub fn first_name(files: List(snippet_model.File)) -> String {
  case files {
    [snippet_model.File(name:, ..), ..] -> name
    [] -> ""
  }
}

pub fn remove_first_name(names: List(String), target: String) -> List(String) {
  case names {
    [] -> []
    [name, ..rest] ->
      case name == target {
        True -> rest
        False -> [name, ..remove_first_name(rest, target)]
      }
  }
}

pub fn name_exists(files: List(snippet_model.File), filename: String) -> Bool {
  case files {
    [] -> False
    [snippet_model.File(name:, ..), ..rest] ->
      name == filename || name_exists(rest, filename)
  }
}

pub fn name_at(files: List(snippet_model.File), index: Int) -> String {
  case files, index {
    [snippet_model.File(name:, ..), ..], 0 -> name
    [_first, ..rest], _ -> name_at(rest, index - 1)
    [], _ -> ""
  }
}

pub fn name_exists_except(
  files: List(snippet_model.File),
  filename: String,
  skip_index: Int,
) -> Bool {
  case files, skip_index {
    [], _ -> False
    [snippet_model.File(_name, ..), ..rest], 0 ->
      name_exists_except(rest, filename, -1)
    [snippet_model.File(name:, ..), ..rest], _ ->
      name == filename || name_exists_except(rest, filename, skip_index - 1)
  }
}

pub fn content_at(files: List(snippet_model.File), index: Int) -> String {
  case files, index {
    [snippet_model.File(content:, ..), ..], 0 -> content
    [_first, ..rest], _ -> content_at(rest, index - 1)
    [], _ -> ""
  }
}

pub fn update_content_at(
  files: List(snippet_model.File),
  index: Int,
  content: String,
) -> List(snippet_model.File) {
  case files, index {
    [snippet_model.File(name:, ..), ..rest], 0 -> [
      snippet_model.File(name:, content:),
      ..rest
    ]
    [first, ..rest], _ -> [first, ..update_content_at(rest, index - 1, content)]
    [], _ -> []
  }
}

pub fn rename_at(
  files: List(snippet_model.File),
  index: Int,
  filename: String,
) -> List(snippet_model.File) {
  case files, index {
    [snippet_model.File(content:, ..), ..rest], 0 -> [
      snippet_model.File(name: filename, content:),
      ..rest
    ]
    [first, ..rest], _ -> [first, ..rename_at(rest, index - 1, filename)]
    [], _ -> []
  }
}

pub fn remove_at(
  files: List(snippet_model.File),
  index: Int,
) -> List(snippet_model.File) {
  case files, index {
    [_first, ..rest], 0 -> rest
    [first, ..rest], _ -> [first, ..remove_at(rest, index - 1)]
    [], _ -> []
  }
}

pub fn valid_name(filename: String) -> Bool {
  filename != "" && string.length(filename) <= 30
}

pub fn truncated_name(filename: String) -> String {
  case list.reverse(string.split(filename, ".")) {
    [extension, stem, ..rest] ->
      string_helpers.truncate_stem_middle(
        string.join(list.reverse([stem, ..rest]), "."),
        10,
      )
      <> "."
      <> extension
    _ -> string_helpers.truncate_stem_middle(filename, 10)
  }
}
