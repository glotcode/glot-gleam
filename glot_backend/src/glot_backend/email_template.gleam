import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string
import glot_core/email/email_address_model
import glot_core/email/email_model

pub type EmailTemplateName {
  LoginTokenTemplate
  AccountDeletedTemplate
}

pub type EmailTemplate {
  EmailTemplate(
    name: EmailTemplateName,
    subject_template: String,
    text_body_template: String,
    html_body_template: Option(String),
  )
}

pub fn to_db_name(name: EmailTemplateName) -> String {
  case name {
    LoginTokenTemplate -> "login_token"
    AccountDeletedTemplate -> "account_deleted"
  }
}

pub fn from_db_name(name: String) -> Result(EmailTemplateName, String) {
  case name {
    "login_token" -> Ok(LoginTokenTemplate)
    "account_deleted" -> Ok(AccountDeletedTemplate)
    _ -> Error("Unknown email template: " <> name)
  }
}

pub fn allowed_tokens(name: EmailTemplateName) -> List(String) {
  case name {
    LoginTokenTemplate -> ["token"]
    AccountDeletedTemplate -> []
  }
}

pub fn are_allowed_tokens(
  name: EmailTemplateName,
  tokens: List(String),
) -> Bool {
  let allowed = allowed_tokens(name)
  list.all(tokens, fn(token) { list.contains(allowed, token) })
}

pub fn render_email_template(
  template: EmailTemplate,
  to: email_address_model.EmailAddress,
  variables: Dict(String, String),
) -> Result(email_model.Email, String) {
  let allowed_tokens = allowed_tokens(template.name)
  use _ <- result.try(validate_variables(template.name, variables))
  use subject <- result.try(render_template(
    template.subject_template,
    variables,
  ))
  use text_body <- result.try(render_template(
    template.text_body_template,
    variables,
  ))
  use html_body <- result.try(case template.html_body_template {
    option.Some(html) ->
      render_template(html, variables)
      |> result.map(option.Some)
    option.None -> Ok(option.None)
  })

  let template_tokens =
    collect_tokens(template.subject_template)
    |> list.append(collect_tokens(template.text_body_template))
    |> list.append(case template.html_body_template {
      option.Some(html) -> collect_tokens(html)
      option.None -> []
    })

  case are_allowed_tokens(template.name, template_tokens) {
    True ->
      Ok(email_model.Email(
        to: to,
        subject: subject,
        text_body: text_body,
        html_body: html_body,
      ))
    False ->
      Error(
        "Email template contains unsupported tokens for "
        <> to_db_name(template.name)
        <> ". Allowed tokens: "
        <> string.join(allowed_tokens, with: ", "),
      )
  }
}

fn validate_variables(
  template_name: EmailTemplateName,
  variables: Dict(String, String),
) -> Result(Nil, String) {
  let allowed = allowed_tokens(template_name)
  let variable_names =
    variables
    |> dict.to_list
    |> list.map(fn(entry) { entry.0 })

  case are_allowed_tokens(template_name, variable_names) {
    True -> Ok(Nil)
    False ->
      Error(
        "Unexpected email template variables for "
        <> to_db_name(template_name)
        <> ". Allowed tokens: "
        <> string.join(allowed, with: ", "),
      )
  }
}

fn render_template(
  template: String,
  variables: Dict(String, String),
) -> Result(String, String) {
  case string.split_once(template, "{{") {
    Error(_) -> Ok(template)
    Ok(#(prefix, remainder)) ->
      case string.split_once(remainder, "}}") {
        Error(_) -> Error("Unclosed template token in email template")
        Ok(#(raw_token, suffix)) -> {
          let token = string.trim(raw_token)
          use value <- result.try(
            dict.get(variables, token)
            |> result.map_error(fn(_) {
              "Missing email template variable: " <> token
            }),
          )
          use rendered_suffix <- result.try(render_template(suffix, variables))
          Ok(prefix <> value <> rendered_suffix)
        }
      }
  }
}

fn collect_tokens(template: String) -> List(String) {
  case string.split_once(template, "{{") {
    Error(_) -> []
    Ok(#(_, remainder)) ->
      case string.split_once(remainder, "}}") {
        Error(_) -> []
        Ok(#(raw_token, suffix)) -> [
          string.trim(raw_token),
          ..collect_tokens(suffix)
        ]
      }
  }
}
