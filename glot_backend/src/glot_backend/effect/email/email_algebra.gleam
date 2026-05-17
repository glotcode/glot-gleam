import glot_backend/effect/error
import glot_core/email/email_model.{type Email, type SendEmailResult}

pub type EmailEffect(next) {
  SendEmail(Email, fn(Result(SendEmailResult, error.Error)) -> next)
}

pub fn map(effect: EmailEffect(a), f: fn(a) -> b) -> EmailEffect(b) {
  case effect {
    SendEmail(message, next) -> SendEmail(message, fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  SendEmailEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    SendEmailEffectName -> "send_email"
  }
}
