import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/admin/job_log_dto
import glot_core/job_log_model
import youid/uuid.{type Uuid}

pub type JobLogEffect(next) {
  ListJobLogs(
    request: job_log_dto.ListJobLogsRequest,
    next: fn(List(job_log_model.JobLog)) -> next,
  )
  GetJobLog(id: Uuid, next: fn(option.Option(job_log_model.JobLog)) -> next)
  DeleteJobLogBefore(
    before: Timestamp,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub fn map(effect: JobLogEffect(a), f: fn(a) -> b) -> JobLogEffect(b) {
  case effect {
    ListJobLogs(request:, next:) ->
      ListJobLogs(request: request, next: fn(value) { f(next(value)) })
    GetJobLog(id:, next:) ->
      GetJobLog(id: id, next: fn(value) { f(next(value)) })
    DeleteJobLogBefore(before:, next:) ->
      DeleteJobLogBefore(before: before, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  ListJobLogsEffectName
  GetJobLogEffectName
  DeleteJobLogBeforeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    ListJobLogsEffectName -> "list_job_logs"
    GetJobLogEffectName -> "get_job_log"
    DeleteJobLogBeforeEffectName -> "delete_job_log_before"
  }
}
