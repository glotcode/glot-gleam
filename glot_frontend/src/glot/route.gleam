import gleam/uri.{type Uri}
import lustre/attribute.{type Attribute}

pub type Route {
  Home
  NewSnippet(language: String)
  NotFound(uri: Uri)
}

pub fn from_uri(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] | [""] -> Home

    ["new", language] -> NewSnippet(language: language)

    _ -> NotFound(uri:)
  }
}

pub fn to_string(route: Route) -> String {
  case route {
    Home -> "/"
    NewSnippet(language) -> "/new/" <> language
    NotFound(_) -> ""
  }
}

pub fn href(route: Route) -> Attribute(msg) {
  attribute.href(to_string(route))
}
