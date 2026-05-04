import gleam/list
import gleam/option
import gleam/uri.{type Uri}
import lustre/attribute.{type Attribute}
import youid/uuid

pub type Route {
  Home
  Login
  Account
  Admin
  AdminJobs
  AdminJob(id: uuid.Uuid)
  AdminConfig
  AdminRateLimits
  AccountSnippets(after: option.Option(String), before: option.Option(String))
  Snippets(
    after: option.Option(String),
    before: option.Option(String),
    username: option.Option(String),
  )
  NewSnippet(language: String)
  Snippet(slug: String)
  NotFound(uri: Uri)
}

pub fn from_uri(uri: Uri) -> Route {
  case uri.path_segments(uri.path) {
    [] | [""] -> Home
    ["login"] -> Login
    ["account"] -> Account
    ["admin"] -> Admin
    ["admin", "jobs"] -> AdminJobs
    ["admin", "jobs", job_id] ->
      case uuid.from_string(job_id) {
        Ok(id) -> AdminJob(id)
        Error(_) -> NotFound(uri:)
      }
    ["admin", "config"] -> AdminConfig
    ["admin", "rate-limits"] -> AdminRateLimits
    ["account", "snippets"] -> {
      let #(after, before, _) = snippet_query_params(uri)
      AccountSnippets(after:, before:)
    }
    ["snippets"] -> {
      let #(after, before, username) = snippet_query_params(uri)
      Snippets(after:, before:, username:)
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
    Admin -> "/admin"
    AdminJobs -> "/admin/jobs"
    AdminJob(id) -> "/admin/jobs/" <> uuid.to_string(id)
    AdminConfig -> "/admin/config"
    AdminRateLimits -> "/admin/rate-limits"
    AccountSnippets(after:, before:) -> {
      let query = snippet_query_string(after, before, option.None)
      case query {
        option.Some(query) -> "/account/snippets?" <> query
        option.None -> "/account/snippets"
      }
    }
    Snippets(after:, before:, username:) -> {
      let query = snippet_query_string(after, before, username)
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

pub fn name(route: Route) -> String {
  case route {
    Home -> "home"
    Login -> "login"
    Account -> "account"
    Admin -> "admin"
    AdminJobs -> "admin_jobs"
    AdminJob(_) -> "admin_job"
    AdminConfig -> "admin_config"
    AdminRateLimits -> "admin_rate_limits"
    AccountSnippets(_, _) -> "account_snippets"
    Snippets(_, _, _) -> "snippets"
    NewSnippet(_) -> "new_snippet"
    Snippet(_) -> "snippet"
    NotFound(_) -> "not_found"
  }
}

pub fn href(route: Route) -> Attribute(msg) {
  attribute.href(to_string(route))
}

pub fn path_and_query(route: Route) -> #(String, option.Option(String)) {
  case route {
    AccountSnippets(after:, before:) -> #(
      "/account/snippets",
      snippet_query_string(after, before, option.None),
    )
    Snippets(after:, before:, username:) -> #(
      "/snippets",
      snippet_query_string(after, before, username),
    )
    _ -> #(to_string(route), option.None)
  }
}

fn snippet_query_params(
  uri: Uri,
) -> #(option.Option(String), option.Option(String), option.Option(String)) {
  case uri.query {
    option.Some(query) ->
      case uri.parse_query(query) {
        Ok(params) -> #(
          query_param(params, "after"),
          query_param(params, "before"),
          query_param(params, "username"),
        )
        Error(_) -> #(option.None, option.None, option.None)
      }
    option.None -> #(option.None, option.None, option.None)
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
  username: option.Option(String),
) -> option.Option(String) {
  let pairs =
    []
    |> prepend_query_param("after", after)
    |> prepend_query_param("before", before)
    |> prepend_query_param("username", username)
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
