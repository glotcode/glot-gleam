import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/effect/core/core
import glot_backend/effect/error
import glot_backend/effect/types
import glot_backend/email_message
import glot_backend/job
import glot_backend/log
import glot_core/rate_limit
import youid/uuid.{type Uuid}

pub fn new_token(length: Int) -> types.Program(String) {
  types.Impure(types.CoreEffect(core.NewToken(length, types.Pure)))
}

pub fn system_time() -> types.Program(Timestamp) {
  types.Impure(types.CoreEffect(core.SystemTime(types.Pure)))
}

pub fn uuid_v7() -> types.Program(Uuid) {
  types.Impure(types.CoreEffect(core.UuidV7(types.Pure)))
}

pub fn info(fields: log.Fields) -> types.Program(Nil) {
  types.Impure(types.CoreEffect(core.Log(log.Info, fields, types.Pure(Nil))))
}

pub fn warn(fields: log.Fields) -> types.Program(Nil) {
  types.Impure(types.CoreEffect(core.Log(log.Warn, fields, types.Pure(Nil))))
}

pub fn attempt_send_email(
  message: email_message.EmailMessage,
) -> types.Program(Result(Nil, error.SendEmailError)) {
  types.Impure(types.CoreEffect(core.AttemptSendEmail(message, types.Pure)))
}

pub fn send_email(message: email_message.EmailMessage) -> types.Program(Nil) {
  types.Impure(types.CoreEffect(core.AttemptSendEmail(message, fn(send_result) {
    case send_result {
      Ok(_) -> types.Pure(Nil)
      Error(err) -> types.Fail(error.SendEmailError(err))
    }
  })))
}

pub fn db_get_next_job(
  now: Timestamp,
  pending_status: job.Status,
  running_status: job.Status,
) -> types.Program(option.Option(job.Job)) {
  types.Impure(types.CoreEffect(core.GetNextJob(
    now: now,
    pending_status: pending_status,
    running_status: running_status,
    next: types.Pure,
  )))
}

pub fn db_count_user_actions_by_ip(
  windows windows: List(rate_limit.Window),
  ip ip: option.Option(String),
  action action: ApiAction,
) -> types.Program(List(rate_limit.WindowCount)) {
  types.Impure(types.CoreEffect(core.CountUserActionsByIp(
    windows: windows,
    ip: ip,
    action: action,
    next: types.Pure,
  )))
}

pub fn db_count_user_actions_by_user(
  windows windows: List(rate_limit.Window),
  user_id user_id: option.Option(Uuid),
  action action: ApiAction,
) -> types.Program(List(rate_limit.WindowCount)) {
  types.Impure(types.CoreEffect(core.CountUserActionsByUser(
    windows: windows,
    user_id: user_id,
    action: action,
    next: types.Pure,
  )))
}

pub fn insert_job(job job: job.Job) -> types.Program(Nil) {
  types.Impure(types.CoreEffect(core.InsertJob(job, command_next)))
}

pub fn insert_user_action(
  id id: Uuid,
  request_id request_id: Uuid,
  action action: ApiAction,
  ip ip: option.Option(String),
  user_id user_id: option.Option(Uuid),
  created_at created_at: Timestamp,
) -> types.Program(Nil) {
  types.Impure(types.CoreEffect(core.InsertUserAction(
    id: id,
    request_id: request_id,
    action: action,
    ip: ip,
    user_id: user_id,
    created_at: created_at,
    next: command_next,
  )))
}

pub fn mark_job_done(
  id id: Uuid,
  completed_at completed_at: Timestamp,
) -> types.Program(Nil) {
  types.Impure(types.CoreEffect(core.MarkJobDone(id, completed_at, command_next)))
}

pub fn reschedule_job(
  id id: Uuid,
  run_at run_at: Timestamp,
  last_error last_error: option.Option(String),
  updated_at updated_at: Timestamp,
) -> types.Program(Nil) {
  types.Impure(types.CoreEffect(core.RescheduleJob(
    id: id,
    run_at: run_at,
    last_error: last_error,
    updated_at: updated_at,
    next: command_next,
  )))
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> types.Program(Nil) {
  case result {
    Ok(_) -> types.Pure(Nil)
    Error(err) -> types.Fail(error.CommandError(err))
  }
}
