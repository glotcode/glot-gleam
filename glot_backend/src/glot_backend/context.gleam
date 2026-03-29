import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import glot_core/rate_limit.{type RateLimit}
import pog

pub type Context {
  Context(
    db: pog.Connection,
    config: Config,
    regexes: Regexes,
    timestamp: Timestamp,
    client_info: ClientInfo,
  )
}

pub type Config {
  Config(
    static_base_path: String,
    postgres: PostgresConfig,
    docker_run: DockerRunConfig,
    rate_limits: RateLimitsConfig,
  )
}

pub fn config_from_dict(values: Dict(String, String)) -> Result(Config, String) {
  use static_base_path <- result.try(lookup(values, "STATIC_BASE_PATH"))
  use postgres <- result.try(postgres_config_from_dict(values))
  use docker_run <- result.try(docker_run_config_from_dict(values))

  Ok(Config(
    static_base_path: static_base_path,
    postgres: postgres,
    docker_run: docker_run,
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

pub type RateLimitsConfig {
  RateLimitsConfig(
    send_login_token: List(RateLimit),
    login: List(RateLimit),
    run: List(RateLimit),
  )
}

fn rate_limits_config_from_dict(
  values: Dict(String, String),
) -> RateLimitsConfig {
  RateLimitsConfig(
    send_login_token: lookup_rate_limits(values, "SEND_LOGIN_TOKEN"),
    login: lookup_rate_limits(values, "LOGIN"),
    run: lookup_rate_limits(values, "RUN"),
  )
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
  ClientInfo(ip: option.Option(String), user_agent: option.Option(String))
}
