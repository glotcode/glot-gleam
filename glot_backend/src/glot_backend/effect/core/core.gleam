import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/log
import glot_core/rate_limit
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
  CountUserActionsByIp(
    windows: List(rate_limit.Window),
    ip: option.Option(String),
    action: ApiAction,
    next: fn(List(rate_limit.WindowCount)) -> next,
  )
  CountUserActionsByUser(
    windows: List(rate_limit.Window),
    user_id: option.Option(Uuid),
    action: ApiAction,
    next: fn(List(rate_limit.WindowCount)) -> next,
  )
  InsertUserAction(
    id: Uuid,
    request_id: Uuid,
    action: ApiAction,
    ip: option.Option(String),
    user_id: option.Option(Uuid),
    created_at: Timestamp,
    next: fn(Result(Nil, error.DbCommandError)) -> next,
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
    CountUserActionsByIp(windows:, ip:, action:, next:) ->
      CountUserActionsByIp(
        windows: windows,
        ip: ip,
        action: action,
        next: fn(value) { f(next(value)) },
      )
    CountUserActionsByUser(windows:, user_id:, action:, next:) ->
      CountUserActionsByUser(
        windows: windows,
        user_id: user_id,
        action: action,
        next: fn(value) { f(next(value)) },
      )
    InsertUserAction(
      id: id,
      request_id: request_id,
      action: action,
      ip: ip,
      user_id: user_id,
      created_at: created_at,
      next: next,
    ) ->
      InsertUserAction(
        id: id,
        request_id: request_id,
        action: action,
        ip: ip,
        user_id: user_id,
        created_at: created_at,
        next: fn(value) { f(next(value)) },
      )
  }
}

pub type EffectName {
  NewTokenEffectName
  SystemTimeEffectName
  UuidV7EffectName
  LogEffectName
  SendEmailEffectName
  CountUserActionsByIpEffectName
  CountUserActionsByUserEffectName
  InsertUserActionEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    NewTokenEffectName -> "new_token"
    SystemTimeEffectName -> "system_time"
    UuidV7EffectName -> "uuid_v7"
    LogEffectName -> "log"
    SendEmailEffectName -> "send_email"
    CountUserActionsByIpEffectName -> "count_user_actions_by_ip"
    CountUserActionsByUserEffectName -> "count_user_actions_by_user"
    InsertUserActionEffectName -> "insert_user_action"
  }
}
