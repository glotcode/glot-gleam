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
  AdminApiLogs
  AdminApiLog(id: uuid.Uuid)
  AdminPeriodicJobs
  AdminPeriodicJob(id: uuid.Uuid)
  AdminUsers
  AdminUser(id: uuid.Uuid)
  AdminJobs
  AdminJob(id: uuid.Uuid)
  AdminJobLogs
  AdminJobLog(id: uuid.Uuid)
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
    ["admin", "logs", "api"] -> AdminApiLogs
    ["admin", "logs", "api", id] ->
      case uuid.from_string(id) {
        Ok(id) -> AdminApiLog(id)
        Error(_) -> NotFound(uri:)
      }
    ["admin", "periodic-jobs"] -> AdminPeriodicJobs
    ["admin", "periodic-jobs", job_id] ->
      case uuid.from_string(job_id) {
        Ok(id) -> AdminPeriodicJob(id)
        Error(_) -> NotFound(uri:)
      }
    ["admin", "users"] -> AdminUsers
    ["admin", "users", user_id] ->
      case uuid.from_string(user_id) {
        Ok(id) -> AdminUser(id)
        Error(_) -> NotFound(uri:)
      }
    ["admin", "jobs"] -> AdminJobs
    ["admin", "jobs", job_id] ->
      case uuid.from_string(job_id) {
        Ok(id) -> AdminJob(id)
        Error(_) -> NotFound(uri:)
      }
    ["admin", "logs", "job-logs"] -> AdminJobLogs
    ["admin", "logs", "job-logs", id] ->
      case uuid.from_string(id) {
        Ok(id) -> AdminJobLog(id)
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
    AdminApiLogs -> "/admin/logs/api"
    AdminApiLog(id) -> "/admin/logs/api/" <> uuid.to_string(id)
    AdminPeriodicJobs -> "/admin/periodic-jobs"
    AdminPeriodicJob(id) -> "/admin/periodic-jobs/" <> uuid.to_string(id)
    AdminUsers -> "/admin/users"
    AdminUser(id) -> "/admin/users/" <> uuid.to_string(id)
    AdminJobs -> "/admin/jobs"
    AdminJob(id) -> "/admin/jobs/" <> uuid.to_string(id)
    AdminJobLogs -> "/admin/logs/job-logs"
    AdminJobLog(id) -> "/admin/logs/job-logs/" <> uuid.to_string(id)
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
    AdminApiLogs -> "admin_api_logs"
    AdminApiLog(_) -> "admin_api_log"
    AdminPeriodicJobs -> "admin_periodic_jobs"
    AdminPeriodicJob(_) -> "admin_periodic_job"
    AdminUsers -> "admin_users"
    AdminUser(_) -> "admin_user"
    AdminJobs -> "admin_jobs"
    AdminJob(_) -> "admin_job"
    AdminJobLogs -> "admin_job_logs"
    AdminJobLog(_) -> "admin_job_log"
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
