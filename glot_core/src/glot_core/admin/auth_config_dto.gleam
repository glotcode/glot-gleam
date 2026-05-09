import gleam/dynamic/decode
import gleam/json

pub type AuthConfigResponse {
  AuthConfigResponse(
    login_token_max_age: Int,
    session_token_max_age: Int,
    session_cookie_max_age: Int,
  )
}

pub type UpsertAuthConfigRequest {
  UpsertAuthConfigRequest(
    login_token_max_age: Int,
    session_token_max_age: Int,
    session_cookie_max_age: Int,
  )
}

pub fn response_decoder() -> decode.Decoder(AuthConfigResponse) {
  use login_token_max_age <- decode.field("loginTokenMaxAge", decode.int)
  use session_token_max_age <- decode.field("sessionTokenMaxAge", decode.int)
  use session_cookie_max_age <- decode.field("sessionCookieMaxAge", decode.int)
  decode.success(AuthConfigResponse(
    login_token_max_age:,
    session_token_max_age:,
    session_cookie_max_age:,
  ))
}

pub fn decoder() -> decode.Decoder(UpsertAuthConfigRequest) {
  use login_token_max_age <- decode.field("loginTokenMaxAge", decode.int)
  use session_token_max_age <- decode.field("sessionTokenMaxAge", decode.int)
  use session_cookie_max_age <- decode.field("sessionCookieMaxAge", decode.int)
  decode.success(UpsertAuthConfigRequest(
    login_token_max_age:,
    session_token_max_age:,
    session_cookie_max_age:,
  ))
}

pub fn encode_response(response: AuthConfigResponse) -> json.Json {
  json.object([
    #("loginTokenMaxAge", json.int(response.login_token_max_age)),
    #("sessionTokenMaxAge", json.int(response.session_token_max_age)),
    #("sessionCookieMaxAge", json.int(response.session_cookie_max_age)),
  ])
}

pub fn encode_request(request: UpsertAuthConfigRequest) -> json.Json {
  json.object([
    #("loginTokenMaxAge", json.int(request.login_token_max_age)),
    #("sessionTokenMaxAge", json.int(request.session_token_max_age)),
    #("sessionCookieMaxAge", json.int(request.session_cookie_max_age)),
  ])
}
