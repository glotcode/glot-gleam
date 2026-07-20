import gleam/option.{type Option}
import glot_backend/email/model/template.{
  type EmailTemplate, type EmailTemplateName,
}
import glot_backend/system/effect/error/db_error

pub type TemplateStore {
  TemplateStore(
    list: fn() -> Result(List(EmailTemplate), db_error.DbQueryError),
    get: fn(EmailTemplateName) ->
      Result(Option(EmailTemplate), db_error.DbQueryError),
    update: fn(EmailTemplate) -> Result(Nil, db_error.DbCommandError),
  )
}
