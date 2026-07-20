import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/logging/api_log/effect/algebra as api_log_algebra
import glot_backend/logging/effect/effect as logging_effect
import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/program_types
import glot_core/admin/api_log_dto
import glot_core/api_log_model.{type ApiLogDetail, type ApiLogSummary}
import youid/uuid.{type Uuid}

pub fn list(
  request: api_log_dto.ListApiLogsRequest,
) -> program_types.Program(List(ApiLogSummary)) {
  program_types.Impure(
    program_types.DbEffect(list_effect(request, program_types.Pure)),
  )
}

pub fn get(id: Uuid) -> program_types.Program(Option(ApiLogDetail)) {
  program_types.Impure(
    program_types.DbEffect(get_effect(id, program_types.Pure)),
  )
}

pub fn delete_before(before: Timestamp) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_before_effect(before, command_next)),
  )
}

fn command_next(
  result: Result(Nil, db_error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.database_command_error(err))
  }
}

fn delete_before_effect(
  before: Timestamp,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  logging_effect.api_log(api_log_algebra.DeleteApiLogBefore(
    before: before,
    next: next,
  ))
}

fn list_effect(
  request: api_log_dto.ListApiLogsRequest,
  next: fn(List(ApiLogSummary)) -> next,
) -> program_types.DbEffect(next) {
  logging_effect.api_log(api_log_algebra.ListApiLogs(
    request: request,
    next: next,
  ))
}

fn get_effect(
  id: Uuid,
  next: fn(Option(ApiLogDetail)) -> next,
) -> program_types.DbEffect(next) {
  logging_effect.api_log(api_log_algebra.GetApiLog(id: id, next: next))
}
