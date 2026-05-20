import gleam/dict.{type Dict}
import gleam/int
import gleam/option.{type Option}
import gleam/regexp
import gleam/result
import gleam/time/timestamp.{type Timestamp}
import glot_backend/erlang
import youid/uuid.{type Uuid}

pub type Context {
  Context(
    config: Config,
    regexes: Regexes,
    request_id: Uuid,
    // started_at is not a timestamp. Used for duration measurement
    started_at: Int,
    deadline_at_monotonic_ns: Option(Int),
    timestamp: Timestamp,
    client_info: ClientInfo,
  )
}

pub fn remaining_timeout_ms(ctx: Context) -> Option(Int) {
  case ctx.deadline_at_monotonic_ns {
    option.Some(deadline_at_ns) -> {
      let remaining_ns = deadline_at_ns - erlang.perf_counter_ns()
      let remaining_ms = remaining_ns / 1_000_000

      case remaining_ms > 0 {
        True -> option.Some(remaining_ms)
        False -> option.Some(1)
      }
    }
    option.None -> option.None
  }
}

pub type Config {
  Config(
    app_env: AppEnv,
    encryption_key: String,
    static_base_path: String,
    postgres: PostgresConfig,
    passkey: PasskeyConfig,
  )
}

pub type PasskeyConfig {
  PasskeyConfig(
    origin: String,
    rp_id: String,
    challenge_timeout_seconds: Int,
  )
}

pub type AppEnv {
  Dev
  Prod
}

pub fn config_from_dict(
  values: Dict(String, String),
) -> Result(Config, String) {
  use app_env <- result.try(
    lookup(values, "APP_ENV")
    |> result.try(app_env_from_string),
  )
  use encryption_key <- result.try(lookup(values, "ENCRYPTION_KEY"))
  use static_base_path <- result.try(lookup(values, "STATIC_BASE_PATH"))
  use postgres <- result.try(postgres_config_from_dict(values))
  let passkey = passkey_config_from_dict(values)

  Ok(Config(
    app_env: app_env,
    encryption_key: encryption_key,
    static_base_path: static_base_path,
    postgres: postgres,
    passkey: passkey,
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

fn passkey_config_from_dict(values: Dict(String, String)) -> PasskeyConfig {
  let defaults = default_passkey_config()
  let origin =
    dict.get(values, "PASSKEY_ORIGIN")
    |> option.from_result()
    |> option.unwrap(defaults.origin)
  let rp_id =
    dict.get(values, "PASSKEY_RP_ID")
    |> option.from_result()
    |> option.unwrap(defaults.rp_id)
  let challenge_timeout_seconds =
    dict.get(values, "PASSKEY_CHALLENGE_TIMEOUT_SECONDS")
    |> option.from_result()
    |> option.map(string_to_int)
    |> option.unwrap(Ok(defaults.challenge_timeout_seconds))
    |> result.unwrap(defaults.challenge_timeout_seconds)

  PasskeyConfig(
    origin: origin,
    rp_id: rp_id,
    challenge_timeout_seconds: challenge_timeout_seconds,
  )
}

pub fn default_passkey_config() -> PasskeyConfig {
  PasskeyConfig(
    origin: "http://localhost:5173",
    rp_id: "localhost",
    challenge_timeout_seconds: 120,
  )
}

fn lookup(dict: Dict(String, String), key: String) -> Result(String, String) {
  dict.get(dict, key)
  |> result.map_error(fn(_) { "Missing key: " <> key })
}

fn string_to_int(s: String) -> Result(Int, String) {
  int.parse(s)
  |> result.map_error(fn(_) { "Invalid integer: " <> s })
}

pub fn app_env_to_string(app_env: AppEnv) -> String {
  case app_env {
    Dev -> "dev"
    Prod -> "prod"
  }
}

pub fn app_env_from_string(s: String) -> Result(AppEnv, String) {
  case s {
    "dev" -> Ok(Dev)
    "prod" -> Ok(Prod)
    _ -> Error("Invalid APP_ENV: " <> s)
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
