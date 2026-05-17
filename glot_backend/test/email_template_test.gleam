import gleam/dict
import gleam/json
import gleam/option
import gleam/regexp
import gleam/time/timestamp
import gleeunit
import glot_backend/email_template
import glot_core/email/email_address_model
import glot_core/email/email_model

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn render_email_template_replaces_tokens_test() {
  let template =
    email_template.EmailTemplate(
      name: email_template.LoginTokenTemplate,
      subject_template: "Your login token",
      text_body_template: "Your login token is: {{ token }}",
      html_body_template: option.Some("<p>{{token}}</p>"),
      updated_at: test_timestamp(),
    )

  let assert Ok(rendered) =
    email_template.render_email_template(
      template,
      email_model.EmailSender(
        address: email_model.default_from_address(),
        name: option.Some("glot.io"),
      ),
      email_address_model.EmailAddress("user@example.com"),
      dict.from_list([#("token", "123456")]),
    )

  assert rendered
    == email_model.Email(
      from: email_model.EmailSender(
        address: email_model.default_from_address(),
        name: option.Some("glot.io"),
      ),
      to: email_address_model.EmailAddress("user@example.com"),
      subject: "Your login token",
      text_body: "Your login token is: 123456",
      html_body: option.Some("<p>123456</p>"),
    )
}

pub fn email_decoder_defaults_from_address_for_legacy_jobs_test() {
  let assert Ok(is_email) = regexp.from_string(email_address_model.pattern)
  let assert Ok(decoded) =
    json.parse(
      "{\"to\":\"user@example.com\",\"subject\":\"Hello\",\"text_body\":\"Body\",\"html_body\":null}",
      email_model.decoder(is_email),
    )

  assert decoded
    == email_model.Email(
      from: email_model.default_from_sender(),
      to: email_address_model.EmailAddress("user@example.com"),
      subject: "Hello",
      text_body: "Body",
      html_body: option.None,
    )
}

pub fn render_email_template_rejects_missing_tokens_test() {
  let template =
    email_template.EmailTemplate(
      name: email_template.LoginTokenTemplate,
      subject_template: "Subject",
      text_body_template: "Missing {{token}}",
      html_body_template: option.None,
      updated_at: test_timestamp(),
    )

  let assert Error(message) =
    email_template.render_email_template(
      template,
      email_model.default_from_sender(),
      email_address_model.EmailAddress("user@example.com"),
      dict.new(),
    )

  assert message == "Missing email template variable: token"
}

pub fn render_email_template_rejects_unsupported_tokens_test() {
  let template =
    email_template.EmailTemplate(
      name: email_template.AccountDeletedTemplate,
      subject_template: "Subject",
      text_body_template: "Hello {{token}}",
      html_body_template: option.None,
      updated_at: test_timestamp(),
    )

  let assert Error(message) =
    email_template.render_email_template(
      template,
      email_model.default_from_sender(),
      email_address_model.EmailAddress("user@example.com"),
      dict.from_list([#("token", "123456")]),
    )

  assert message
    == "Email template contains unsupported tokens for account_deleted. Supported tokens: "
}

fn test_timestamp() {
  timestamp.from_unix_seconds_and_nanoseconds(1_700_000_000, 0)
}
