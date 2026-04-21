import gleam/uri.{type Uri}
import lustre/attribute.{type Attribute}

pub type Route {
  Home
  Login
  Account
  NewSnippet(language: String)
  Snippet(slug: String)
  NotFound(uri: Uri)
}

pub fn from_uri(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] | [""] -> Home
    ["login"] -> Login
    ["account"] -> Account
    ["new", language] -> NewSnippet(language: language)
    ["snippets", slug] -> Snippet(slug: slug)
    _ -> NotFound(uri:)
  }
}

pub fn to_string(route: Route) -> String {
  case route {
    Home -> "/"
    Login -> "/login"
    Account -> "/account"
    NewSnippet(language) -> "/new/" <> language
    Snippet(slug) -> "/snippets/" <> slug
    NotFound(_) -> ""
  }
}

pub fn href(route: Route) -> Attribute(msg) {
  attribute.href(to_string(route))
}
