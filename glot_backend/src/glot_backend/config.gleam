import gleam/dict.{type Dict}

pub type Config {
  Config(
    static_base_path: String,
    docker_run_base_url: String,
    docker_run_access_token: String,
  )
}

pub fn from_dict(values: Dict(String, String)) -> Result(Config, String) {
  use static_base_path <- try_get(values, "STATIC_BASE_PATH")
  use docker_run_base_url <- try_get(values, "DOCKER_RUN_BASE_URL")
  use docker_run_access_token <- try_get(values, "DOCKER_RUN_ACCESS_TOKEN")

  Ok(Config(
    static_base_path: static_base_path,
    docker_run_base_url: docker_run_base_url,
    docker_run_access_token: docker_run_access_token,
  ))
}

fn try_get(
  dict: Dict(String, b),
  key: String,
  apply fun: fn(b) -> Result(c, String),
) -> Result(c, String) {
  case dict.get(dict, key) {
    Error(_) -> Error("Missing env key: " <> key)
    Ok(x) -> fun(x)
  }
}
