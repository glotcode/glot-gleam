import gleam/dynamic/decode
import gleam/json
import gleam/regexp
import glot_core/email

pub type LoginTokenRequest {
  LoginTokenRequest(email: email.Email)
}

pub fn encode_login_token_request(req: LoginTokenRequest) -> json.Json {
  json.object([
    #("email", email.encode(req.email)),
  ])
}

pub fn login_token_request_decoder(
  is_email: regexp.Regexp,
) -> decode.Decoder(LoginTokenRequest) {
  use email <- decode.field("email", email.decoder(is_email))
  decode.success(LoginTokenRequest(email: email))
}

pub type LoginRequest {
  LoginRequest(email: email.Email, token: String)
}

pub fn encode_login_request(req: LoginRequest) -> json.Json {
  json.object([
    #("email", email.encode(req.email)),
    #("token", json.string(req.token)),
  ])
}

pub fn login_request_decoder(
  is_email: regexp.Regexp,
) -> decode.Decoder(LoginRequest) {
  use email <- decode.field("email", email.decoder(is_email))
  use token <- decode.field("token", decode.string)
  decode.success(LoginRequest(email: email, token: token))
}
