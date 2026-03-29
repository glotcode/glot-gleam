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
    regexp: Regexp,
    timestamp: Timestamp,
    client_ip: option.Option(String),
    client_user_agent: option.Option(String),
  )
}

pub type Config {
  Config(
    static_base_path: String,
    postgres_host: String,
    postgres_port: Int,
    postgres_db: String,
    postgres_user: String,
    postgres_pass: String,
    postgres_pool_size: Int,
    docker_run_base_url: String,
    docker_run_access_token: String,
    rate_limits: RateLimitsConfig,
  )
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

pub fn config_from_dict(values: Dict(String, String)) -> Result(Config, String) {
  use static_base_path <- result.try(lookup(values, "STATIC_BASE_PATH"))
  use postgres_host <- result.try(lookup(values, "POSTGRES_HOST"))
  use postgres_port <- result.try(
    lookup(values, "POSTGRES_PORT")
    |> result.try(string_to_int),
  )
  use postgres_db <- result.try(lookup(values, "POSTGRES_DB"))
  use postgres_user <- result.try(lookup(values, "POSTGRES_USER"))
  use postgres_pass <- result.try(lookup(values, "POSTGRES_PASS"))
  use postgres_pool_size <- result.try(
    lookup(values, "POSTGRES_POOL_SIZE")
    |> result.try(string_to_int),
  )
  use docker_run_base_url <- result.try(lookup(values, "DOCKER_RUN_BASE_URL"))
  use docker_run_access_token <- result.try(lookup(
    values,
    "DOCKER_RUN_ACCESS_TOKEN",
  ))

  Ok(Config(
    static_base_path: static_base_path,
    postgres_host: postgres_host,
    postgres_port: postgres_port,
    postgres_db: postgres_db,
    postgres_user: postgres_user,
    postgres_pass: postgres_pass,
    postgres_pool_size: postgres_pool_size,
    docker_run_base_url: docker_run_base_url,
    docker_run_access_token: docker_run_access_token,
    rate_limits: rate_limits_config_from_dict(values),
  ))
}

fn lookup(dict: Dict(String, String), key: String) -> Result(String, String) {
  dict.get(dict, key)
  |> result.map_error(fn(_) { "Missing key: " <> key })
}

fn string_to_int(s: String) -> Result(Int, String) {
  int.parse(s)
  |> result.map_error(fn(_) { "Invalid integer: " <> s })
}

pub type Regexp {
  Regexp(is_email: regexp.Regexp)
}
