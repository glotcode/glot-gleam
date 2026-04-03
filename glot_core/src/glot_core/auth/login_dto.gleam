import gleam/dynamic/decode
import gleam/json
import gleam/regexp
import glot_core/email/email_address_model

pub type LoginRequest {
  LoginRequest(email: email_address_model.EmailAddress, token: String)
}

pub fn encode(req: LoginRequest) -> json.Json {
  json.object([
    #("email", email_address_model.encode(req.email)),
    #("token", json.string(req.token)),
  ])
}

pub fn decoder(is_email: regexp.Regexp) -> decode.Decoder(LoginRequest) {
  use email <- decode.field("email", email_address_model.decoder(is_email))
  use token <- decode.field("token", decode.string)
  decode.success(LoginRequest(email: email, token: token))
}
