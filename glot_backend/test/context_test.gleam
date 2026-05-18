import gleam/dict
import gleeunit
import glot_backend/context

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn app_env_from_string_accepts_dev_test() {
  assert context.app_env_from_string("dev") == Ok(context.Dev)
}

pub fn app_env_from_string_accepts_prod_test() {
  assert context.app_env_from_string("prod") == Ok(context.Prod)
}

pub fn app_env_from_string_rejects_unknown_value_test() {
  assert context.app_env_from_string("staging") == Error("Invalid APP_ENV: staging")
}

pub fn config_from_dict_rejects_invalid_app_env_test() {
  let values =
    dict.from_list([
      #("APP_ENV", "staging"),
      #("ENCRYPTION_KEY", "test"),
      #("STATIC_BASE_PATH", "/tmp"),
      #("POSTGRES_HOST", "localhost"),
      #("POSTGRES_PORT", "5432"),
      #("POSTGRES_DB", "glot"),
      #("POSTGRES_USER", "glot"),
      #("POSTGRES_PASS", "glot"),
      #("POSTGRES_POOL_SIZE", "1"),
    ])

  assert context.config_from_dict(values) == Error("Invalid APP_ENV: staging")
}
