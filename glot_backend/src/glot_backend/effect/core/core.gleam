import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/log
import youid/uuid.{type Uuid}

pub type CoreEffect(next) {
  NewToken(Int, fn(String) -> next)
  SystemTime(fn(Timestamp) -> next)
  UuidV7(fn(Uuid) -> next)
  Log(log.Level, log.Fields, next)
  SendEmail(
    email_message.EmailMessage,
    fn(Result(Nil, error.SendEmailError)) -> next,
  )
}

pub fn map(effect: CoreEffect(a), f: fn(a) -> b) -> CoreEffect(b) {
  case effect {
    NewToken(length, next) -> NewToken(length, fn(value) { f(next(value)) })
    SystemTime(next) -> SystemTime(fn(value) { f(next(value)) })
    UuidV7(next) -> UuidV7(fn(value) { f(next(value)) })
    Log(level, fields, next) -> Log(level, fields, f(next))
    SendEmail(message, next) ->
      SendEmail(message, fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  NewTokenEffectName
  SystemTimeEffectName
  UuidV7EffectName
  LogEffectName
  SendEmailEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    NewTokenEffectName -> "new_token"
    SystemTimeEffectName -> "system_time"
    UuidV7EffectName -> "uuid_v7"
    LogEffectName -> "log"
    SendEmailEffectName -> "send_email"
  }
}
