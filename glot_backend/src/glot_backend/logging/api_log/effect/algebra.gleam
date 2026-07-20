import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/system/effect/error/db_error
import glot_core/admin/api_log_dto
import glot_core/api_log_model.{type ApiLogDetail, type ApiLogSummary}
import youid/uuid.{type Uuid}

pub type ApiLogEffect(next) {
  ListApiLogs(
    request: api_log_dto.ListApiLogsRequest,
    next: fn(List(ApiLogSummary)) -> next,
  )
  GetApiLog(id: Uuid, next: fn(Option(ApiLogDetail)) -> next)
  DeleteApiLogBefore(
    before: Timestamp,
    next: fn(Result(Nil, db_error.DbCommandError)) -> next,
  )
}

pub fn map(effect: ApiLogEffect(a), f: fn(a) -> b) -> ApiLogEffect(b) {
  case effect {
    ListApiLogs(request:, next:) ->
      ListApiLogs(request: request, next: fn(value) { f(next(value)) })
    GetApiLog(id:, next:) ->
      GetApiLog(id: id, next: fn(value) { f(next(value)) })
    DeleteApiLogBefore(before:, next:) ->
      DeleteApiLogBefore(before: before, next: fn(value) { f(next(value)) })
  }
}

pub type EffectName {
  ListApiLogsEffectName
  GetApiLogEffectName
  DeleteApiLogBeforeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    ListApiLogsEffectName -> "list_api_logs"
    GetApiLogEffectName -> "get_api_log"
    DeleteApiLogBeforeEffectName -> "delete_api_log_before"
  }
}
