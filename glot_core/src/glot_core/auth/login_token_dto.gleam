import gleam/dynamic/decode
import gleam/json
import gleam/regexp
import glot_core/email/email_address_model

pub type LoginTokenRequest {
  LoginTokenRequest(email: email_address_model.EmailAddress)
}

pub fn encode(req: LoginTokenRequest) -> json.Json {
  json.object([
    #("email", email_address_model.encode(req.email)),
  ])
}

pub fn decoder(is_email: regexp.Regexp) -> decode.Decoder(LoginTokenRequest) {
  use email <- decode.field("email", email_address_model.decoder(is_email))
  decode.success(LoginTokenRequest(email: email))
}
