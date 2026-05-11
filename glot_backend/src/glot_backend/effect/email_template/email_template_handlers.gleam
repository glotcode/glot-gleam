import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glot_backend/effect/error
import glot_backend/email_template
import glot_backend/helpers/db_helpers
import glot_backend/sql
import pog

pub type EmailTemplateHandlers {
  EmailTemplateHandlers(
    list_email_templates: fn() ->
      Result(List(email_template.EmailTemplate), error.DbQueryError),
    get_email_template_by_name: fn(email_template.EmailTemplateName) ->
      Result(option.Option(email_template.EmailTemplate), error.DbQueryError),
    update_email_template: fn(email_template.EmailTemplate) ->
      Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> EmailTemplateHandlers {
  EmailTemplateHandlers(
    list_email_templates: fn() { list_email_templates(db) },
    get_email_template_by_name: fn(name) {
      get_email_template_by_name(db, name)
    },
    update_email_template: fn(template) { update_email_template(db, template) },
  )
}

pub fn list_email_templates(
  db: pog.Connection,
) -> Result(List(email_template.EmailTemplate), error.DbQueryError) {
  let to_error = fn(err) { error.DbQueryError(string.inspect(err)) }
  use returned <- result.try(db_helpers.query(
    db,
    sql.list_email_templates(),
    to_error,
  ))

  returned.rows
  |> list.map(row_to_list_template)
  |> result.all
  |> result.map_error(error.DbQueryError)
}

pub fn get_email_template_by_name(
  db: pog.Connection,
  name: email_template.EmailTemplateName,
) -> Result(option.Option(email_template.EmailTemplate), error.DbQueryError) {
  let to_error = fn(err) { error.DbQueryError(string.inspect(err)) }
  use returned <- result.try(db_helpers.query(
    db,
    sql.get_email_template_by_name(email_template.to_db_name(name)),
    to_error,
  ))

  case returned.rows {
    [] -> Ok(option.None)
    [row] ->
      row_to_get_template(row)
      |> result.map(option.Some)
      |> result.map_error(error.DbQueryError)
    _ -> Error(error.DbQueryError("Expected at most one email template row"))
  }
}

pub fn update_email_template(
  db: pog.Connection,
  template: email_template.EmailTemplate,
) -> Result(Nil, error.DbCommandError) {
  let to_error = fn(err) { error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(
    db,
    sql.update_email_template(
      name: email_template.to_db_name(template.name),
      subject_template: template.subject_template,
      text_body_template: template.text_body_template,
      html_body_template: template.html_body_template,
      updated_at: template.updated_at,
    ),
    to_error,
  )
  |> result.map(fn(_) { Nil })
}

fn row_to_list_template(
  row: sql.ListEmailTemplates,
) -> Result(email_template.EmailTemplate, String) {
  use name <- result.try(email_template.from_db_name(row.name))
  Ok(email_template.EmailTemplate(
    name: name,
    subject_template: row.subject_template,
    text_body_template: row.text_body_template,
    html_body_template: row.html_body_template,
    updated_at: row.updated_at,
  ))
}

fn row_to_get_template(
  row: sql.GetEmailTemplateByName,
) -> Result(email_template.EmailTemplate, String) {
  use name <- result.try(email_template.from_db_name(row.name))
  Ok(email_template.EmailTemplate(
    name: name,
    subject_template: row.subject_template,
    text_body_template: row.text_body_template,
    html_body_template: row.html_body_template,
    updated_at: row.updated_at,
  ))
}
