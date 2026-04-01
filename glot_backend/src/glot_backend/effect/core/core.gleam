import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/api_action.{type ApiAction}
import glot_backend/effect/error
import glot_backend/email_message
import glot_backend/job
import glot_backend/log
import glot_core/rate_limit
import youid/uuid.{type Uuid}

pub type CoreQueryName {
  GetNextJobQuery
  CountUserActionsByIpQuery
  CountUserActionsByUserQuery
}

pub type CoreCommandName {
  InsertJobCommand
  InsertUserActionCommand
  MarkJobDoneCommand
  RescheduleJobCommand
}

pub type CoreCommand {
  InsertJob(job.Job)
  InsertUserAction(
    id: Uuid,
    request_id: Uuid,
    action: ApiAction,
    ip: option.Option(String),
    user_id: option.Option(Uuid),
    created_at: Timestamp,
  )
  MarkJobDone(id: Uuid, completed_at: Timestamp)
  RescheduleJob(
    id: Uuid,
    run_at: Timestamp,
    last_error: option.Option(String),
    updated_at: Timestamp,
  )
}

pub type CoreEffect(next) {
  NewToken(Int, fn(String) -> next)
  SystemTime(fn(Timestamp) -> next)
  UuidV7(fn(Uuid) -> next)
  Log(log.Level, log.Fields, next)
  AttemptSendEmail(
    email_message.EmailMessage,
    fn(Result(Nil, error.SendEmailError)) -> next,
  )
  GetNextJob(
    now: Timestamp,
    pending_status: job.Status,
    running_status: job.Status,
    next: fn(option.Option(job.Job)) -> next,
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
  RunCommand(
    CoreCommand,
    fn(Result(Nil, error.DbCommandError)) -> next,
  )
}

pub fn map(effect: CoreEffect(a), f: fn(a) -> b) -> CoreEffect(b) {
  case effect {
    NewToken(length, next) -> NewToken(length, fn(value) { f(next(value)) })
    SystemTime(next) -> SystemTime(fn(value) { f(next(value)) })
    UuidV7(next) -> UuidV7(fn(value) { f(next(value)) })
    Log(level, fields, next) -> Log(level, fields, f(next))
    AttemptSendEmail(message, next) ->
      AttemptSendEmail(message, fn(value) { f(next(value)) })
    GetNextJob(now:, pending_status:, running_status:, next:) ->
      GetNextJob(
        now: now,
        pending_status: pending_status,
        running_status: running_status,
        next: fn(value) { f(next(value)) },
      )
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
    RunCommand(command, next) -> RunCommand(command, fn(value) { f(next(value)) })
  }
}

pub fn command_name(command: CoreCommand) -> CoreCommandName {
  case command {
    InsertJob(_) -> InsertJobCommand
    InsertUserAction(_, _, _, _, _, _) -> InsertUserActionCommand
    MarkJobDone(_, _) -> MarkJobDoneCommand
    RescheduleJob(_, _, _, _) -> RescheduleJobCommand
  }
}
