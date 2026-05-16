import gleam/dynamic/decode
import gleam/json

pub type AuthConfigResponse {
  AuthConfigResponse(
    login_token_max_age: Int,
    session_token_max_age: Int,
    session_cookie_max_age: Int,
    session_refresh_interval_seconds: Int,
    session_previous_token_grace_seconds: Int,
    session_heartbeat_interval_seconds: Int,
  )
}

pub type UpsertAuthConfigRequest {
  UpsertAuthConfigRequest(
    login_token_max_age: Int,
    session_token_max_age: Int,
    session_cookie_max_age: Int,
    session_refresh_interval_seconds: Int,
    session_previous_token_grace_seconds: Int,
    session_heartbeat_interval_seconds: Int,
  )
}

pub fn response_decoder() -> decode.Decoder(AuthConfigResponse) {
  use login_token_max_age <- decode.field("loginTokenMaxAge", decode.int)
  use session_token_max_age <- decode.field("sessionTokenMaxAge", decode.int)
  use session_cookie_max_age <- decode.field("sessionCookieMaxAge", decode.int)
  use session_refresh_interval_seconds <- decode.field(
    "sessionRefreshIntervalSeconds",
    decode.int,
  )
  use session_previous_token_grace_seconds <- decode.field(
    "sessionPreviousTokenGraceSeconds",
    decode.int,
  )
  use session_heartbeat_interval_seconds <- decode.field(
    "sessionHeartbeatIntervalSeconds",
    decode.int,
  )
  decode.success(AuthConfigResponse(
    login_token_max_age:,
    session_token_max_age:,
    session_cookie_max_age:,
    session_refresh_interval_seconds:,
    session_previous_token_grace_seconds:,
    session_heartbeat_interval_seconds:,
  ))
}

pub fn decoder() -> decode.Decoder(UpsertAuthConfigRequest) {
  use login_token_max_age <- decode.field("loginTokenMaxAge", decode.int)
  use session_token_max_age <- decode.field("sessionTokenMaxAge", decode.int)
  use session_cookie_max_age <- decode.field("sessionCookieMaxAge", decode.int)
  use session_refresh_interval_seconds <- decode.field(
    "sessionRefreshIntervalSeconds",
    decode.int,
  )
  use session_previous_token_grace_seconds <- decode.field(
    "sessionPreviousTokenGraceSeconds",
    decode.int,
  )
  use session_heartbeat_interval_seconds <- decode.field(
    "sessionHeartbeatIntervalSeconds",
    decode.int,
  )
  decode.success(UpsertAuthConfigRequest(
    login_token_max_age:,
    session_token_max_age:,
    session_cookie_max_age:,
    session_refresh_interval_seconds:,
    session_previous_token_grace_seconds:,
    session_heartbeat_interval_seconds:,
  ))
}

pub fn encode_response(response: AuthConfigResponse) -> json.Json {
  json.object([
    #("loginTokenMaxAge", json.int(response.login_token_max_age)),
    #("sessionTokenMaxAge", json.int(response.session_token_max_age)),
    #("sessionCookieMaxAge", json.int(response.session_cookie_max_age)),
    #(
      "sessionRefreshIntervalSeconds",
      json.int(response.session_refresh_interval_seconds),
    ),
    #(
      "sessionPreviousTokenGraceSeconds",
      json.int(response.session_previous_token_grace_seconds),
    ),
    #(
      "sessionHeartbeatIntervalSeconds",
      json.int(response.session_heartbeat_interval_seconds),
    ),
  ])
}

pub fn encode_request(request: UpsertAuthConfigRequest) -> json.Json {
  json.object([
    #("loginTokenMaxAge", json.int(request.login_token_max_age)),
    #("sessionTokenMaxAge", json.int(request.session_token_max_age)),
    #("sessionCookieMaxAge", json.int(request.session_cookie_max_age)),
    #(
      "sessionRefreshIntervalSeconds",
      json.int(request.session_refresh_interval_seconds),
    ),
    #(
      "sessionPreviousTokenGraceSeconds",
      json.int(request.session_previous_token_grace_seconds),
    ),
    #(
      "sessionHeartbeatIntervalSeconds",
      json.int(request.session_heartbeat_interval_seconds),
    ),
  ])
}
