import gleam/result
import glot_backend/app_config/decoder/value
import glot_backend/app_config/model/entry.{type AppConfigEntry}
import glot_backend/auth/model/config.{type AuthConfig, type PasskeyConfig}

pub fn auth(
  current: AuthConfig,
  entry: AppConfigEntry,
) -> Result(AuthConfig, String) {
  use decoded <- result.try(value.int("auth", entry))

  case entry.key {
    "login_token_max_age" ->
      Ok(config.AuthConfig(..current, login_token_max_age: decoded))
    "session_token_max_age" ->
      Ok(config.AuthConfig(..current, session_token_max_age: decoded))
    "session_idle_timeout_seconds" ->
      Ok(config.AuthConfig(..current, session_idle_timeout_seconds: decoded))
    "session_cookie_max_age" ->
      Ok(config.AuthConfig(..current, session_cookie_max_age: decoded))
    "session_refresh_interval_seconds" ->
      Ok(
        config.AuthConfig(..current, session_refresh_interval_seconds: decoded),
      )
    "session_previous_token_grace_seconds" ->
      Ok(
        config.AuthConfig(
          ..current,
          session_previous_token_grace_seconds: decoded,
        ),
      )
    "session_heartbeat_interval_seconds" ->
      Ok(
        config.AuthConfig(
          ..current,
          session_heartbeat_interval_seconds: decoded,
        ),
      )
    _ -> Ok(current)
  }
}

pub fn passkey(
  current: PasskeyConfig,
  entry: AppConfigEntry,
) -> Result(PasskeyConfig, String) {
  case entry.key {
    "origin" -> {
      use decoded <- result.try(value.string("passkey", entry))
      Ok(config.PasskeyConfig(..current, origin: decoded))
    }
    "rp_id" -> {
      use decoded <- result.try(value.string("passkey", entry))
      Ok(config.PasskeyConfig(..current, rp_id: decoded))
    }
    "challenge_timeout_seconds" -> {
      use decoded <- result.try(value.int("passkey", entry))
      Ok(config.PasskeyConfig(..current, challenge_timeout_seconds: decoded))
    }
    _ -> Ok(current)
  }
}
