import gleam/time/timestamp.{type Timestamp}
import glot_backend/crypto_token.{type Alphabet}
import glot_backend/log
import youid/uuid.{type Uuid}

pub type BasicEffect(next) {
  NewToken(Int, Alphabet, fn(String) -> next)
  SystemTime(fn(Timestamp) -> next)
  UuidV7(fn(Uuid) -> next)
  Log(log.Level, log.Fields, next)
}

pub fn map(effect: BasicEffect(a), f: fn(a) -> b) -> BasicEffect(b) {
  case effect {
    NewToken(length, alphabet, next) ->
      NewToken(length, alphabet, fn(value) { f(next(value)) })
    SystemTime(next) -> SystemTime(fn(value) { f(next(value)) })
    UuidV7(next) -> UuidV7(fn(value) { f(next(value)) })
    Log(level, fields, next) -> Log(level, fields, f(next))
  }
}

pub type EffectName {
  NewTokenEffectName
  SystemTimeEffectName
  UuidV7EffectName
  LogEffectName(log.Level)
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    NewTokenEffectName -> "new_token"
    SystemTimeEffectName -> "system_time"
    UuidV7EffectName -> "uuid_v7"
    LogEffectName(level) -> log.level_to_string(level)
  }
}
