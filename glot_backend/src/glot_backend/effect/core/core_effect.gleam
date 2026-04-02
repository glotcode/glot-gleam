import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/effect/core/core
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/log
import glot_core/rate_limit
import youid/uuid.{type Uuid}

pub fn new_token(length: Int) -> effect_model.Program(String) {
  effect_model.Impure(
    effect_model.CoreEffect(core.NewToken(length, effect_model.Pure)),
  )
}

pub fn system_time() -> effect_model.Program(Timestamp) {
  effect_model.Impure(
    effect_model.CoreEffect(core.SystemTime(effect_model.Pure)),
  )
}

pub fn uuid_v7() -> effect_model.Program(Uuid) {
  effect_model.Impure(effect_model.CoreEffect(core.UuidV7(effect_model.Pure)))
}

pub fn info(fields: log.Fields) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.CoreEffect(core.Log(log.Info, fields, effect_model.Pure(Nil))),
  )
}

pub fn warn(fields: log.Fields) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.CoreEffect(core.Log(log.Warn, fields, effect_model.Pure(Nil))),
  )
}

pub fn attempt_send_email(
  message: email_message.EmailMessage,
) -> effect_model.Program(Result(Nil, error.SendEmailError)) {
  effect_model.Impure(
    effect_model.CoreEffect(core.AttemptSendEmail(message, effect_model.Pure)),
  )
}

pub fn db_count_user_actions_by_ip(
  windows windows: List(rate_limit.Window),
  ip ip: option.Option(String),
  action action: ApiAction,
) -> effect_model.Program(List(rate_limit.WindowCount)) {
  effect_model.Impure(
    effect_model.CoreEffect(core.CountUserActionsByIp(
      windows: windows,
      ip: ip,
      action: action,
      next: effect_model.Pure,
    )),
  )
}

pub fn db_count_user_actions_by_user(
  windows windows: List(rate_limit.Window),
  user_id user_id: option.Option(Uuid),
  action action: ApiAction,
) -> effect_model.Program(List(rate_limit.WindowCount)) {
  effect_model.Impure(
    effect_model.CoreEffect(core.CountUserActionsByUser(
      windows: windows,
      user_id: user_id,
      action: action,
      next: effect_model.Pure,
    )),
  )
}

pub fn insert_user_action(
  id id: Uuid,
  request_id request_id: Uuid,
  action action: ApiAction,
  ip ip: option.Option(String),
  user_id user_id: option.Option(Uuid),
  created_at created_at: Timestamp,
) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.CoreEffect(core.InsertUserAction(
      id: id,
      request_id: request_id,
      action: action,
      ip: ip,
      user_id: user_id,
      created_at: created_at,
      next: command_next,
    )),
  )
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> effect_model.Program(Nil) {
  case result {
    Ok(_) -> effect_model.Pure(Nil)
    Error(err) -> effect_model.Fail(error.CommandError(err))
  }
}
