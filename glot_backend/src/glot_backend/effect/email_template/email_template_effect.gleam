import gleam/option
import glot_backend/effect/email_template/email_template_algebra
import glot_backend/effect/program_types
import glot_backend/email_template

pub fn list_email_templates() -> program_types.Program(
  List(email_template.EmailTemplate),
) {
  program_types.Impure(
    program_types.DbEffect(
      program_types.EmailTemplateEffect(
        email_template_algebra.ListEmailTemplates(next: program_types.Pure),
      ),
    ),
  )
}

pub fn get_email_template_by_name(
  name: email_template.EmailTemplateName,
) -> program_types.Program(option.Option(email_template.EmailTemplate)) {
  program_types.Impure(
    program_types.DbEffect(
      program_types.EmailTemplateEffect(
        email_template_algebra.GetEmailTemplateByName(
          name: name,
          next: program_types.Pure,
        ),
      ),
    ),
  )
}

pub fn update_email_template(
  template: email_template.EmailTemplate,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(
      program_types.EmailTemplateEffect(
        email_template_algebra.UpdateEmailTemplate(
          template: template,
          next: program_types.Pure,
        ),
      ),
    ),
  )
}
