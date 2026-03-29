import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/regexp
import gleam/time/timestamp.{type Timestamp}
import glot_core/email
import glot_core/user.{type User}
import youid/uuid.{type Uuid}

pub type LoginToken {
  LoginToken(
    id: Uuid,
    user_id: Uuid,
    token: String,
    created_at: Timestamp,
    used_at: Option(Timestamp),
  )
}

pub type Session {
  Session(
    id: Uuid,
    user: User,
    token: String,
    ip: Option(String),
    user_agent: Option(String),
    created_at: Timestamp,
  )
}

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
