import gleam/dict.{type Dict}
import gleam/int
import gleam/option
import gleam/regexp
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import pog

pub type Context {
  Context(
    db: pog.Connection,
    config: Config,
    regexp: Regexp,
    timestamp: Timestamp,
    client_ip: option.Option(String),
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
  )
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
