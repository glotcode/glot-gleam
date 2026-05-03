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
    docker_run: DockerRunConfig,
    auth: AuthConfig,
    cleanup: CleanupConfig,
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
  use docker_run <- result.try(docker_run_config_from_dict(values))
  use auth <- result.try(auth_config_from_dict(values))

  Ok(Config(
    debug: debug,
    encryption_key: encryption_key,
    static_base_path: static_base_path,
    postgres: postgres,
    docker_run: docker_run,
    auth: auth,
    cleanup: cleanup_config_from_dict(values),
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

pub type CleanupConfig {
  CleanupConfig(
    api_log_retention_days: Int,
    page_log_retention_days: Int,
    pageview_log_retention_days: Int,
    run_log_retention_days: Int,
    job_log_retention_days: Int,
    jobs_retention_days: Int,
    login_tokens_retention_days: Int,
    user_actions_retention_days: Int,
  )
}

fn cleanup_config_from_dict(values: Dict(String, String)) -> CleanupConfig {
  CleanupConfig(
    api_log_retention_days: lookup(values, "CLEANUP_API_LOG_RETENTION_DAYS")
      |> result.try(string_to_int)
      |> result.unwrap(30),
    page_log_retention_days: lookup(values, "CLEANUP_PAGE_LOG_RETENTION_DAYS")
      |> result.try(string_to_int)
      |> result.unwrap(30),
    pageview_log_retention_days: lookup(
      values,
      "CLEANUP_PAGEVIEW_LOG_RETENTION_DAYS",
    )
      |> result.try(string_to_int)
      |> result.unwrap(30),
    run_log_retention_days: lookup(values, "CLEANUP_RUN_LOG_RETENTION_DAYS")
      |> result.try(string_to_int)
      |> result.unwrap(90),
    job_log_retention_days: lookup(values, "CLEANUP_JOB_LOG_RETENTION_DAYS")
      |> result.try(string_to_int)
      |> result.unwrap(90),
    jobs_retention_days: lookup(values, "CLEANUP_JOBS_RETENTION_DAYS")
      |> result.try(string_to_int)
      |> result.unwrap(90),
    login_tokens_retention_days: lookup(
      values,
      "CLEANUP_LOGIN_TOKENS_RETENTION_DAYS",
    )
      |> result.try(string_to_int)
      |> result.unwrap(30),
    user_actions_retention_days: lookup(
      values,
      "CLEANUP_USER_ACTIONS_RETENTION_DAYS",
    )
      |> result.try(string_to_int)
      |> result.unwrap(90),
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
