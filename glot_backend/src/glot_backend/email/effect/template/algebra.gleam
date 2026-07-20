import gleam/option
import glot_backend/email/model/template as email_template

pub type EmailTemplateEffect(next) {
  ListEmailTemplates(next: fn(List(email_template.EmailTemplate)) -> next)
  GetEmailTemplateByName(
    name: email_template.EmailTemplateName,
    next: fn(option.Option(email_template.EmailTemplate)) -> next,
  )
  UpdateEmailTemplate(
    template: email_template.EmailTemplate,
    next: fn(Nil) -> next,
  )
}

pub fn map(
  effect: EmailTemplateEffect(a),
  f: fn(a) -> b,
) -> EmailTemplateEffect(b) {
  case effect {
    ListEmailTemplates(next:) ->
      ListEmailTemplates(next: fn(value) { f(next(value)) })
    GetEmailTemplateByName(name:, next:) ->
      GetEmailTemplateByName(name: name, next: fn(value) { f(next(value)) })
    UpdateEmailTemplate(template:, next:) ->
      UpdateEmailTemplate(template: template, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  ListEmailTemplatesEffectName
  GetEmailTemplateByNameEffectName
  UpdateEmailTemplateEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    ListEmailTemplatesEffectName -> "list_email_templates"
    GetEmailTemplateByNameEffectName -> "get_email_template_by_name"
    UpdateEmailTemplateEffectName -> "update_email_template"
  }
}
