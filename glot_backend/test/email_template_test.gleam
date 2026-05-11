import gleam/dict
import gleam/option
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
    )

  let assert Ok(rendered) =
    email_template.render_email_template(
      template,
      email_address_model.EmailAddress("user@example.com"),
      dict.from_list([#("token", "123456")]),
    )

  assert rendered
    == email_model.Email(
      to: email_address_model.EmailAddress("user@example.com"),
      subject: "Your login token",
      text_body: "Your login token is: 123456",
      html_body: option.Some("<p>123456</p>"),
    )
}

pub fn render_email_template_rejects_missing_tokens_test() {
  let template =
    email_template.EmailTemplate(
      name: email_template.LoginTokenTemplate,
      subject_template: "Subject",
      text_body_template: "Missing {{token}}",
      html_body_template: option.None,
    )

  let assert Error(message) =
    email_template.render_email_template(
      template,
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
    )

  let assert Error(message) =
    email_template.render_email_template(
      template,
      email_address_model.EmailAddress("user@example.com"),
      dict.from_list([#("token", "123456")]),
    )

  assert message
    == "Unexpected email template variables for account_deleted. Allowed tokens: "
}
