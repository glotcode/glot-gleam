import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option}
import gleam/regexp
import glot_core/email/email_address_model

pub type EmailSender {
  EmailSender(address: email_address_model.EmailAddress, name: Option(String))
}

pub type Email {
  Email(
    from: EmailSender,
    to: email_address_model.EmailAddress,
    subject: String,
    text_body: String,
    html_body: Option(String),
  )
}

pub type SendEmailResult {
  SendEmailResult(
    delivered: List(String),
    permanent_bounces: List(String),
    queued: List(String),
  )
}

pub fn recipient_string(message: Email) -> String {
  case message {
    Email(to:, ..) -> email_address_model.to_string(to)
  }
}

pub fn sender_string(message: Email) -> String {
  case message {
    Email(from:, ..) -> sender_address_string(from)
  }
}

pub fn encode(message: Email) -> json.Json {
  case message {
    Email(from:, to:, subject:, text_body:, html_body:) ->
      json.object([
        #("from", encode_sender(from)),
        #("to", email_address_model.encode(to)),
        #("subject", json.string(subject)),
        #("text_body", json.string(text_body)),
        #("html_body", case html_body {
          option.Some(value) -> json.string(value)
          option.None -> json.null()
        }),
      ])
  }
}

pub fn decoder(is_email: regexp.Regexp) -> decode.Decoder(Email) {
  use from <- decode.optional_field(
    "from",
    default_from_sender(),
    sender_decoder(is_email),
  )
  use to <- decode.field("to", email_address_model.decoder(is_email))
  use subject <- decode.field("subject", decode.string)
  use text_body <- decode.field("text_body", decode.string)
  use html_body <- decode.field("html_body", decode.optional(decode.string))
  decode.success(Email(from:, to:, subject:, text_body:, html_body:))
}

pub fn default_from_address() -> email_address_model.EmailAddress {
  email_address_model.EmailAddress("glot@glot.io")
}

pub fn default_from_sender() -> EmailSender {
  EmailSender(address: default_from_address(), name: option.Some("glot"))
}

pub fn sender_address_string(sender: EmailSender) -> String {
  email_address_model.to_string(sender.address)
}

fn encode_sender(sender: EmailSender) -> json.Json {
  case sender.name {
    option.Some(name) ->
      json.object([
        #("address", email_address_model.encode(sender.address)),
        #("name", json.string(name)),
      ])
    option.None -> email_address_model.encode(sender.address)
  }
}

fn sender_decoder(is_email: regexp.Regexp) -> decode.Decoder(EmailSender) {
  decode.one_of(
    decode.map(email_address_model.decoder(is_email), fn(address) {
      EmailSender(address: address, name: option.None)
    }),
    or: [sender_object_decoder(is_email)],
  )
}

fn sender_object_decoder(
  is_email: regexp.Regexp,
) -> decode.Decoder(EmailSender) {
  use address <- decode.field("address", email_address_model.decoder(is_email))
  use name <- decode.field("name", decode.string)
  decode.success(EmailSender(address: address, name: option.Some(name)))
}
