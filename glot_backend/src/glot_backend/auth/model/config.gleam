pub type AuthConfig {
  AuthConfig(
    login_token_max_age: Int,
    session_token_max_age: Int,
    session_idle_timeout_seconds: Int,
    session_cookie_max_age: Int,
    session_refresh_interval_seconds: Int,
    session_previous_token_grace_seconds: Int,
    session_heartbeat_interval_seconds: Int,
  )
}

pub type PasskeyConfig {
  PasskeyConfig(origin: String, rp_id: String, challenge_timeout_seconds: Int)
}
