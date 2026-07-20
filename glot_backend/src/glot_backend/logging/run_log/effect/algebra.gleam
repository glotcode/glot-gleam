import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/admin/run_log_dto
import glot_core/run_log_model.{type RunLog}
import youid/uuid.{type Uuid}

pub type RunLogEffect(next) {
  CreateRunLog(
    run_log: RunLog,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
  ListRunLogs(
    request: run_log_dto.ListRunLogsRequest,
    next: fn(List(RunLog)) -> next,
  )
  GetRunLog(id: Uuid, next: fn(Option(RunLog)) -> next)
  DeleteRunLogBefore(
    before: Timestamp,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub fn map(effect: RunLogEffect(a), f: fn(a) -> b) -> RunLogEffect(b) {
  case effect {
    CreateRunLog(run_log:, next:) ->
      CreateRunLog(run_log: run_log, next: fn(value) { f(next(value)) })
    ListRunLogs(request:, next:) ->
      ListRunLogs(request: request, next: fn(value) { f(next(value)) })
    GetRunLog(id:, next:) ->
      GetRunLog(id: id, next: fn(value) { f(next(value)) })
    DeleteRunLogBefore(before:, next:) ->
      DeleteRunLogBefore(before: before, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  CreateRunLogEffectName
  ListRunLogsEffectName
  GetRunLogEffectName
  DeleteRunLogBeforeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    CreateRunLogEffectName -> "create_run_log"
    ListRunLogsEffectName -> "list_run_logs"
    GetRunLogEffectName -> "get_run_log"
    DeleteRunLogBeforeEffectName -> "delete_run_log_before"
  }
}
