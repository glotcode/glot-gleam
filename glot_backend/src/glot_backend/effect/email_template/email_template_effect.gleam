import gleam/option
import glot_backend/email_template
import glot_backend/effect/email_template/email_template_algebra
import glot_backend/effect/program_types

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
