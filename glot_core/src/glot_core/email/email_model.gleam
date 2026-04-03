import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/regexp
import glot_core/email/email_address_model

pub type Email {
  Email(
    to: email_address_model.EmailAddress,
    subject: String,
    text_body: String,
    html_body: Option(String),
  )
}

pub fn recipient_string(message: Email) -> String {
  case message {
    Email(to:, ..) -> email_address_model.to_string(to)
  }
}

pub fn encode(message: Email) -> json.Json {
  case message {
    Email(to:, subject:, text_body:, html_body:) ->
      json.object([
        #("to", email_address_model.encode(to)),
        #("subject", json.string(subject)),
        #("text_body", json.string(text_body)),
        #(
          "html_body",
          case html_body {
            option.Some(value) -> json.string(value)
            option.None -> json.null()
          },
        ),
      ])
  }
}

pub fn decoder(is_email: regexp.Regexp) -> decode.Decoder(Email) {
  use to <- decode.field("to", email_address_model.decoder(is_email))
  use subject <- decode.field("subject", decode.string)
  use text_body <- decode.field("text_body", decode.string)
  use html_body <- decode.field("html_body", decode.optional(decode.string))
  decode.success(Email(to:, subject:, text_body:, html_body:))
}

pub fn login_token_email(
  to: email_address_model.EmailAddress,
  token: String,
) -> Email {
  Email(
    to: to,
    subject: "Your login token",
    text_body: "Your login token is: " <> token,
    html_body: option.None,
  )
}
