import gleam/dict
import gleam/list
import gleam/option
import glot_backend/email/model/template as email_template
import support/integration/model

pub fn find_email_template_by_name(
  db: model.TestState,
  name: email_template.EmailTemplateName,
) -> option.Option(email_template.EmailTemplate) {
  case dict.get(db.email_templates, email_template.to_db_name(name)) {
    Ok(template) -> option.Some(template)
    Error(_) -> option.None
  }
}

pub fn list_email_templates(
  db: model.TestState,
) -> List(email_template.EmailTemplate) {
  db.email_templates
  |> dict.to_list
  |> list.map(fn(entry) { entry.1 })
}

pub fn update_email_template(
  db: model.TestState,
  template: email_template.EmailTemplate,
) -> model.TestState {
  let key = email_template.to_db_name(template.name)
  model.TestState(
    ..db,
    email_templates: dict.insert(db.email_templates, key, template),
  )
}
