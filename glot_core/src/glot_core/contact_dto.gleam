import gleam/dynamic/decode
import gleam/json
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import glot_core/email/email_address_model.{type EmailAddress}
import glot_core/validation_error.{type ValidationError}

pub const max_message_length = 5000

pub type ContactTopic {
  Privacy
  SecurityVulnerability
  General
}

pub type ContactRequest {
  ContactRequest(email: String, topic: String, message: String, website: String)
}

pub type ValidatedContact {
  ValidatedContact(email: EmailAddress, topic: ContactTopic, message: String)
}

pub fn decoder() -> decode.Decoder(ContactRequest) {
  use email <- decode.field("email", decode.string)
  use topic <- decode.field("topic", decode.string)
  use message <- decode.field("message", decode.string)
  use website <- decode.optional_field("website", "", decode.string)
  decode.success(ContactRequest(email:, topic:, message:, website:))
}

pub fn encode(request: ContactRequest) -> json.Json {
  json.object([
    #("email", json.string(request.email)),
    #("topic", json.string(request.topic)),
    #("message", json.string(request.message)),
    #("website", json.string(request.website)),
  ])
}

pub fn validate(
  request: ContactRequest,
  is_email: regexp.Regexp,
) -> Result(ValidatedContact, ValidationError) {
  let email = string.trim(request.email)
  let message = string.trim(request.message)
  use email <- result.try(
    email_address_model.from_string(is_email, email)
    |> option.to_result(validation_error.InvalidEmail("email")),
  )
  use topic <- result.try(
    topic_from_string(request.topic)
    |> option.to_result(validation_error.InvalidContactTopic),
  )
  use _ <- result.try(case message {
    "" -> Error(validation_error.EmptyField("message"))
    _ ->
      case string.length(message) > max_message_length {
        True ->
          Error(validation_error.FieldTooLong("message", max_message_length))
        False -> Ok(Nil)
      }
  })

  Ok(ValidatedContact(email:, topic:, message:))
}

pub fn topics() -> List(ContactTopic) {
  [Privacy, SecurityVulnerability, General]
}

pub fn topic_to_string(topic: ContactTopic) -> String {
  case topic {
    Privacy -> "privacy"
    SecurityVulnerability -> "security_vulnerability"
    General -> "general"
  }
}

pub fn topic_label(topic: ContactTopic) -> String {
  case topic {
    Privacy -> "Privacy"
    SecurityVulnerability -> "Security vulnerability"
    General -> "General"
  }
}

pub fn topic_from_string(value: String) -> option.Option(ContactTopic) {
  case value {
    "privacy" -> option.Some(Privacy)
    "security_vulnerability" -> option.Some(SecurityVulnerability)
    "general" -> option.Some(General)
    _ -> option.None
  }
}
