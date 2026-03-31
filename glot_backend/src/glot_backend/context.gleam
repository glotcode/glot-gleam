import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/regexp
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action
import glot_core/rate_limit.{type RateLimit}
import pog
import youid/uuid.{type Uuid}

pub type Context {
  Context(
    db: pog.Connection,
    config: Config,
    regexes: Regexes,
    request_id: Uuid,
    timestamp: Timestamp,
    client_info: ClientInfo,
  )
}

pub type Config {
  Config(
    encryption_key: String,
    static_base_path: String,
    postgres: PostgresConfig,
    docker_run: DockerRunConfig,
    auth: AuthConfig,
    rate_limits: RateLimitsConfig,
  )
}

pub fn config_from_dict(values: Dict(String, String)) -> Result(Config, String) {
  use encryption_key <- result.try(lookup(values, "ENCRYPTION_KEY"))
  use static_base_path <- result.try(lookup(values, "STATIC_BASE_PATH"))
  use postgres <- result.try(postgres_config_from_dict(values))
  use docker_run <- result.try(docker_run_config_from_dict(values))
  use auth <- result.try(auth_config_from_dict(values))

  Ok(Config(
    encryption_key: encryption_key,
    static_base_path: static_base_path,
    postgres: postgres,
    docker_run: docker_run,
    auth: auth,
    rate_limits: rate_limits_config_from_dict(values),
  ))
}

pub type PostgresConfig {
  PostgresConfig(
    host: String,
    port: Int,
    db: String,
    user: String,
    pass: String,
    pool_size: Int,
  )
}

fn postgres_config_from_dict(
  values: Dict(String, String),
) -> Result(PostgresConfig, String) {
  use host <- result.try(lookup(values, "POSTGRES_HOST"))
  use port <- result.try(
    lookup(values, "POSTGRES_PORT")
    |> result.try(string_to_int),
  )
  use db <- result.try(lookup(values, "POSTGRES_DB"))
  use user <- result.try(lookup(values, "POSTGRES_USER"))
  use pass <- result.try(lookup(values, "POSTGRES_PASS"))
  use pool_size <- result.try(
    lookup(values, "POSTGRES_POOL_SIZE")
    |> result.try(string_to_int),
  )

  Ok(PostgresConfig(
    host: host,
    port: port,
    db: db,
    user: user,
    pass: pass,
    pool_size: pool_size,
  ))
}

pub type DockerRunConfig {
  DockerRunConfig(base_url: String, access_token: String)
}

fn docker_run_config_from_dict(
  values: Dict(String, String),
) -> Result(DockerRunConfig, String) {
  use base_url <- result.try(lookup(values, "DOCKER_RUN_BASE_URL"))
  use access_token <- result.try(lookup(values, "DOCKER_RUN_ACCESS_TOKEN"))

  Ok(DockerRunConfig(base_url: base_url, access_token: access_token))
}

pub type AuthConfig {
  AuthConfig(
    login_token_max_age: Int,
    session_token_max_age: Int,
    session_cookie_max_age: Int,
  )
}

fn auth_config_from_dict(
  values: Dict(String, String),
) -> Result(AuthConfig, String) {
  use login_token_max_age <- result.try(
    lookup(values, "AUTH_LOGIN_TOKEN_MAX_AGE")
    |> result.try(string_to_int),
  )
  use session_token_max_age <- result.try(
    lookup(values, "AUTH_SESSION_TOKEN_MAX_AGE")
    |> result.try(string_to_int),
  )
  use session_cookie_max_age <- result.try(
    lookup(values, "AUTH_SESSION_COOKIE_MAX_AGE")
    |> result.try(string_to_int),
  )

  Ok(AuthConfig(
    login_token_max_age: login_token_max_age,
    session_token_max_age: session_token_max_age,
    session_cookie_max_age: session_cookie_max_age,
  ))
}

pub type RateLimitsConfig = Dict(api_action.ApiAction, List(RateLimit))

fn rate_limits_config_from_dict(
  values: Dict(String, String),
) -> RateLimitsConfig {
  dict.from_list([
    #(
      api_action.SendLoginTokenAction,
      lookup_rate_limits(values, "SEND_LOGIN_TOKEN"),
    ),
    #(api_action.LoginAction, lookup_rate_limits(values, "LOGIN")),
    #(
      api_action.SnippetCreateAction,
      lookup_rate_limits(values, "SNIPPET_CREATE"),
    ),
    #(api_action.RunAction, lookup_rate_limits(values, "RUN")),
  ])
}

fn lookup_rate_limits(
  dict: Dict(String, String),
  action: String,
) -> List(RateLimit) {
  let second =
    lookup(dict, "RATE_LIMIT_SECOND__" <> action)
    |> result.try(string_to_int)
    |> option.from_result

  let minute =
    lookup(dict, "RATE_LIMIT_MINUTE__" <> action)
    |> result.try(string_to_int)
    |> option.from_result

  let hour =
    lookup(dict, "RATE_LIMIT_HOUR__" <> action)
    |> result.try(string_to_int)
    |> option.from_result

  let day =
    lookup(dict, "RATE_LIMIT_DAY__" <> action)
    |> result.try(string_to_int)
    |> option.from_result

  [
    #(rate_limit.Second, second),
    #(rate_limit.Minute, minute),
    #(rate_limit.Hour, hour),
    #(rate_limit.Day, day),
  ]
  |> list.map(fn(pair) {
    let #(unit, maybe_max) = pair
    option.map(maybe_max, fn(max_requests) {
      rate_limit.RateLimit(unit: unit, max_requests: max_requests)
    })
  })
  |> option.values
}

fn lookup(dict: Dict(String, String), key: String) -> Result(String, String) {
  dict.get(dict, key)
  |> result.map_error(fn(_) { "Missing key: " <> key })
}

fn string_to_int(s: String) -> Result(Int, String) {
  int.parse(s)
  |> result.map_error(fn(_) { "Invalid integer: " <> s })
}

pub type Regexes {
  Regexes(is_email: regexp.Regexp)
}

pub type ClientInfo {
  ClientInfo(
    session_token: Option(String),
    ip: Option(String),
    user_agent: Option(String),
  )
}
