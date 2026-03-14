import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/json
import gleam/regexp
import glot_core/email as core_email

pub type EmailMessage {
  EmailMessage(
    to: core_email.Email,
    subject: String,
    text_body: String,
    html_body: Option(String),
  )
}

pub fn recipient_string(message: EmailMessage) -> String {
  case message {
    EmailMessage(to:, ..) -> core_email.to_string(to)
  }
}

pub fn encode_message(message: EmailMessage) -> json.Json {
  case message {
    EmailMessage(to:, subject:, text_body:, html_body:) ->
      json.object([
        #("to", core_email.encode(to)),
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

pub fn decoder(is_email: regexp.Regexp) -> decode.Decoder(EmailMessage) {
  use to <- decode.field("to", core_email.decoder(is_email))
  use subject <- decode.field("subject", decode.string)
  use text_body <- decode.field("text_body", decode.string)
  use html_body <- decode.field("html_body", decode.optional(decode.string))
  decode.success(EmailMessage(to:, subject:, text_body:, html_body:))
}

pub fn login_token_message(to: core_email.Email, token: String) -> EmailMessage {
  EmailMessage(
    to: to,
    subject: "Your login token",
    text_body: "Your login token is: " <> token,
    html_body: option.None,
  )
}
