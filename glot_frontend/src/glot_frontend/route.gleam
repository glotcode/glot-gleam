import gleam/list
import gleam/option
import gleam/uri.{type Uri}
import lustre/attribute.{type Attribute}

pub type Route {
  Home
  Login
  Account
  Snippets(after: option.Option(String), before: option.Option(String))
  NewSnippet(language: String)
  Snippet(slug: String)
  NotFound(uri: Uri)
}

pub fn from_uri(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] | [""] -> Home
    ["login"] -> Login
    ["account"] -> Account
    ["snippets"] -> {
      let #(after, before) = snippet_query_params(uri)
      Snippets(after:, before:)
    }
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
    Snippets(after:, before:) -> {
      let query = snippet_query_string(after, before)
      case query {
        option.Some(query) -> "/snippets?" <> query
        option.None -> "/snippets"
      }
    }
    NewSnippet(language) -> "/new/" <> language
    Snippet(slug) -> "/snippets/" <> slug
    NotFound(_) -> ""
  }
}

pub fn href(route: Route) -> Attribute(msg) {
  attribute.href(to_string(route))
}

pub fn path_and_query(route: Route) -> #(String, option.Option(String)) {
  case route {
    Snippets(after:, before:) -> #("/snippets", snippet_query_string(after, before))
    _ -> #(to_string(route), option.None)
  }
}

fn snippet_query_params(uri: Uri) -> #(option.Option(String), option.Option(String)) {
  case uri.query {
    option.Some(query) ->
      case uri.parse_query(query) {
        Ok(params) ->
          #(
            query_param(params, "after"),
            query_param(params, "before"),
          )
        Error(_) -> #(option.None, option.None)
      }
    option.None -> #(option.None, option.None)
  }
}

fn query_param(
  params: List(#(String, String)),
  key: String,
) -> option.Option(String) {
  case params |> list.filter(fn(param) { param.0 == key }) |> list.first {
    Ok(param) -> option.Some(param.1)
    Error(_) -> option.None
  }
}

fn snippet_query_string(
  after: option.Option(String),
  before: option.Option(String),
) -> option.Option(String) {
  let pairs =
    []
    |> prepend_query_param("before", before)
    |> prepend_query_param("after", after)
    |> list.reverse

  case pairs {
    [] -> option.None
    _ -> option.Some(uri.query_to_string(pairs))
  }
}

fn prepend_query_param(
  pairs: List(#(String, String)),
  key: String,
  value: option.Option(String),
) -> List(#(String, String)) {
  case value {
    option.Some(value) -> [#(key, value), ..pairs]
    option.None -> pairs
  }
}
