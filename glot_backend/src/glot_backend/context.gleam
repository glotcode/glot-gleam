import gleam/dict.{type Dict}
import gleam/int
import gleam/option.{type Option}
import gleam/regexp
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import youid/uuid.{type Uuid}

pub type Context {
  Context(
    config: Config,
    regexes: Regexes,
    request_id: Uuid,
    // started_at is not a timestamp. Used for duration measurement
    started_at: Int,
    timestamp: Timestamp,
    client_info: ClientInfo,
  )
}

pub type Config {
  Config(
    debug: Bool,
    encryption_key: String,
    static_base_path: String,
    postgres: PostgresConfig,
  )
}

pub fn config_from_dict(values: Dict(String, String)) -> Result(Config, String) {
  let debug =
    lookup(values, "DEBUG")
    |> result.try(string_to_bool)
    |> result.unwrap(False)

  use encryption_key <- result.try(lookup(values, "ENCRYPTION_KEY"))
  use static_base_path <- result.try(lookup(values, "STATIC_BASE_PATH"))
  use postgres <- result.try(postgres_config_from_dict(values))

  Ok(Config(
    debug: debug,
    encryption_key: encryption_key,
    static_base_path: static_base_path,
    postgres: postgres,
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

fn lookup(dict: Dict(String, String), key: String) -> Result(String, String) {
  dict.get(dict, key)
  |> result.map_error(fn(_) { "Missing key: " <> key })
}

fn string_to_int(s: String) -> Result(Int, String) {
  int.parse(s)
  |> result.map_error(fn(_) { "Invalid integer: " <> s })
}

fn string_to_bool(s: String) -> Result(Bool, String) {
  case s {
    "true" -> Ok(True)
    "false" -> Ok(False)
    _ -> Error("Invalid boolean: " <> s)
  }
}

pub type Regexes {
  Regexes(is_email: regexp.Regexp)
}

pub type ClientInfo {
  ClientInfo(
    session_token: Option(String),
    ip: Option(String),
    user_agent: Option(String),
    referrer: Option(String),
  )
}

pub fn empty_client_info() -> ClientInfo {
  ClientInfo(
    session_token: option.None,
    ip: option.None,
    user_agent: option.None,
    referrer: option.None,
  )
}
