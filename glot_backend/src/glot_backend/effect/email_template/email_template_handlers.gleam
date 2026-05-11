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
    get_email_template_by_name: fn(email_template.EmailTemplateName) ->
      Result(option.Option(email_template.EmailTemplate), error.DbQueryError),
  )
}

pub fn new(db: pog.Connection) -> EmailTemplateHandlers {
  EmailTemplateHandlers(get_email_template_by_name: fn(name) {
    get_email_template_by_name(db, name)
  })
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
      row_to_template(row)
      |> result.map(option.Some)
      |> result.map_error(error.DbQueryError)
    _ -> Error(error.DbQueryError("Expected at most one email template row"))
  }
}

fn row_to_template(
  row: sql.GetEmailTemplateByName,
) -> Result(email_template.EmailTemplate, String) {
  use name <- result.try(email_template.from_db_name(row.name))
  Ok(email_template.EmailTemplate(
    name: name,
    subject_template: row.subject_template,
    text_body_template: row.text_body_template,
    html_body_template: row.html_body_template,
  ))
}
