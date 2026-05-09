import gleam/option.{type Option}
import glot_core/admin/api_log_dto
import glot_core/admin/job_log_dto
import glot_core/api_log_model
import glot_core/job_log_model
import youid/uuid.{type Uuid}

pub type AdminLogEffect(next) {
  ListApiLogs(
    request: api_log_dto.ListApiLogsRequest,
    next: fn(List(api_log_model.ApiLogSummary)) -> next,
  )
  GetApiLog(
    id: Uuid,
    next: fn(Option(api_log_model.ApiLogDetail)) -> next,
  )
  ListJobLogs(
    request: job_log_dto.ListJobLogsRequest,
    next: fn(List(job_log_model.JobLog)) -> next,
  )
  GetJobLog(id: Uuid, next: fn(Option(job_log_model.JobLog)) -> next)
}

pub fn map(effect: AdminLogEffect(a), f: fn(a) -> b) -> AdminLogEffect(b) {
  case effect {
    ListApiLogs(request:, next:) ->
      ListApiLogs(request: request, next: fn(value) { f(next(value)) })
    GetApiLog(id:, next:) ->
      GetApiLog(id: id, next: fn(value) { f(next(value)) })
    ListJobLogs(request:, next:) ->
      ListJobLogs(request: request, next: fn(value) { f(next(value)) })
    GetJobLog(id:, next:) ->
      GetJobLog(id: id, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  ListApiLogsEffectName
  GetApiLogEffectName
  ListJobLogsEffectName
  GetJobLogEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    ListApiLogsEffectName -> "list_api_logs"
    GetApiLogEffectName -> "get_api_log"
    ListJobLogsEffectName -> "list_job_logs"
    GetJobLogEffectName -> "get_job_log"
  }
}
