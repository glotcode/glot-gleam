import gleam/list
import gleam/option
import gleam/string

pub type Violation {
  ButtonMissingType
  DialogMissingAccessibleName
  FormControlMissingAccessibleName(tag: String)
  ImageMissingAlternativeText
  BrokenAriaReference(attribute: String, target: String)
}

/// Audits the accessibility contracts that can be verified from server-rendered
/// markup. Keeping this independent of a browser makes it usable by every
/// managed integration test while browser APIs remain behind commands.
pub fn audit_fragment(document: String) -> List(Violation) {
  list.flatten([
    tags(document, "button")
      |> list.filter_map(fn(tag) {
        case attribute(tag, "type") {
          option.Some(_) -> Error(Nil)
          option.None -> Ok(ButtonMissingType)
        }
      }),
    tags(document, "dialog")
      |> list.filter_map(fn(tag) {
        case attribute(tag, "aria-label"), attribute(tag, "aria-labelledby") {
          option.None, option.None -> Ok(DialogMissingAccessibleName)
          _, _ -> Error(Nil)
        }
      }),
    form_control_violations(document, "input"),
    form_control_violations(document, "select"),
    form_control_violations(document, "textarea"),
    tags(document, "img")
      |> list.filter_map(fn(tag) {
        case attribute(tag, "alt") {
          option.Some(_) -> Error(Nil)
          option.None -> Ok(ImageMissingAlternativeText)
        }
      }),
    reference_violations(document, "aria-describedby"),
    reference_violations(document, "aria-labelledby"),
    reference_violations(document, "aria-controls"),
  ])
}

fn form_control_violations(document: String, name: String) -> List(Violation) {
  tags(document, name)
  |> list.filter_map(fn(tag) {
    let exempt =
      name == "input"
      && case attribute(tag, "type") {
        option.Some("hidden") | option.Some("button") | option.Some("submit") ->
          True
        _ -> False
      }
    let explicitly_named =
      attribute(tag, "aria-label") != option.None
      || attribute(tag, "aria-labelledby") != option.None
    let labelled_by_element = case attribute(tag, "id") {
      option.Some(id) -> string.contains(document, "for=\"" <> id <> "\"")
      option.None -> False
    }
    case exempt || explicitly_named || labelled_by_element {
      True -> Error(Nil)
      False -> Ok(FormControlMissingAccessibleName(name))
    }
  })
}

fn reference_violations(document: String, name: String) -> List(Violation) {
  document
  |> string.split(on: name <> "=\"")
  |> drop_first
  |> list.flat_map(fn(rest) {
    let value = rest |> string.split(on: "\"") |> first_or_empty
    value
    |> string.split(on: " ")
    |> list.filter_map(fn(target) {
      case
        target != "" && !string.contains(document, "id=\"" <> target <> "\"")
      {
        True -> Ok(BrokenAriaReference(name, target))
        False -> Error(Nil)
      }
    })
  })
}

fn tags(document: String, name: String) -> List(String) {
  document
  |> string.split(on: "<" <> name)
  |> drop_first
  |> list.map(fn(rest) { rest |> string.split(on: ">") |> first_or_empty })
}

fn attribute(tag: String, name: String) -> option.Option(String) {
  case string.split(tag, on: name <> "=\"") {
    [_, rest, ..] ->
      case string.split(rest, on: "\"") {
        [value, ..] -> option.Some(value)
        _ -> option.None
      }
    _ -> option.None
  }
}

fn drop_first(items: List(value)) -> List(value) {
  case items {
    [_, ..rest] -> rest
    [] -> []
  }
}

fn first_or_empty(items: List(String)) -> String {
  case items {
    [first, ..] -> first
    [] -> ""
  }
}
