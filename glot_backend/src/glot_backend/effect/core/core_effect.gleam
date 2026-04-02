import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/effect/core/core
import glot_backend/effect/program_types
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/log
import glot_core/rate_limit
import youid/uuid.{type Uuid}

pub fn new_token(length: Int) -> program_types.Program(String) {
  program_types.Impure(
    program_types.CoreEffect(core.NewToken(length, program_types.Pure)),
  )
}

pub fn system_time() -> program_types.Program(Timestamp) {
  program_types.Impure(
    program_types.CoreEffect(core.SystemTime(program_types.Pure)),
  )
}

pub fn uuid_v7() -> program_types.Program(Uuid) {
  program_types.Impure(program_types.CoreEffect(core.UuidV7(program_types.Pure)))
}

pub fn info(fields: log.Fields) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.CoreEffect(core.Log(log.Info, fields, program_types.Pure(Nil))),
  )
}

pub fn warn(fields: log.Fields) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.CoreEffect(core.Log(log.Warn, fields, program_types.Pure(Nil))),
  )
}

pub fn send_email(
  message: email_message.EmailMessage,
) -> program_types.Program(Result(Nil, error.SendEmailError)) {
  program_types.Impure(
    program_types.CoreEffect(core.SendEmail(message, program_types.Pure)),
  )
}

pub fn db_count_user_actions_by_ip(
  windows windows: List(rate_limit.Window),
  ip ip: option.Option(String),
  action action: ApiAction,
) -> program_types.Program(List(rate_limit.WindowCount)) {
  program_types.Impure(
    program_types.CoreEffect(core.CountUserActionsByIp(
      windows: windows,
      ip: ip,
      action: action,
      next: program_types.Pure,
    )),
  )
}

pub fn db_count_user_actions_by_user(
  windows windows: List(rate_limit.Window),
  user_id user_id: option.Option(Uuid),
  action action: ApiAction,
) -> program_types.Program(List(rate_limit.WindowCount)) {
  program_types.Impure(
    program_types.CoreEffect(core.CountUserActionsByUser(
      windows: windows,
      user_id: user_id,
      action: action,
      next: program_types.Pure,
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
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.CoreEffect(core.InsertUserAction(
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
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}
