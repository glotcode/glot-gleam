import gleam/list
import gleam/option
import gleam/result
import gleam/string
import glot_backend/email/model/template as email_template
import glot_backend/email/ports/template_store
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error
import glot_core/validation_error

pub fn new(db: db_helpers.Db) -> template_store.TemplateStore {
  template_store.TemplateStore(
    list: fn() { list_email_templates(db) },
    get: fn(name) { get_email_template_by_name(db, name) },
    update: fn(template) { update_email_template(db, template) },
  )
}

pub fn list_email_templates(
  db: db_helpers.Db,
) -> Result(List(email_template.EmailTemplate), db_error.DbQueryError) {
  let to_error = fn(err) { db_error.DbQueryError(string.inspect(err)) }
  use returned <- result.try(db_helpers.query(
    db,
    sql.list_email_templates(),
    to_error,
  ))

  returned.rows
  |> list.map(row_to_list_template)
  |> result.all
  |> result.map_error(validation_error.to_string)
  |> result.map_error(db_error.DbQueryError)
}

pub fn get_email_template_by_name(
  db: db_helpers.Db,
  name: email_template.EmailTemplateName,
) -> Result(option.Option(email_template.EmailTemplate), db_error.DbQueryError) {
  let to_error = fn(err) { db_error.DbQueryError(string.inspect(err)) }
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
      |> result.map_error(validation_error.to_string)
      |> result.map_error(db_error.DbQueryError)
    _ -> Error(db_error.DbQueryError("Expected at most one email template row"))
  }
}

pub fn update_email_template(
  db: db_helpers.Db,
  template: email_template.EmailTemplate,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

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
) -> Result(email_template.EmailTemplate, validation_error.ValidationError) {
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
) -> Result(email_template.EmailTemplate, validation_error.ValidationError) {
  use name <- result.try(email_template.from_db_name(row.name))
  Ok(email_template.EmailTemplate(
    name: name,
    subject_template: row.subject_template,
    text_body_template: row.text_body_template,
    html_body_template: row.html_body_template,
    updated_at: row.updated_at,
  ))
}
