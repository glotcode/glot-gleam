import gleam/option
import glot_backend/email_template

pub type EmailTemplateEffect(next) {
  GetEmailTemplateByName(
    name: email_template.EmailTemplateName,
    next: fn(option.Option(email_template.EmailTemplate)) -> next,
  )
}

pub fn map(
  effect: EmailTemplateEffect(a),
  f: fn(a) -> b,
) -> EmailTemplateEffect(b) {
  case effect {
    GetEmailTemplateByName(name:, next:) ->
      GetEmailTemplateByName(name: name, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  GetEmailTemplateByNameEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetEmailTemplateByNameEffectName -> "get_email_template_by_name"
  }
}
