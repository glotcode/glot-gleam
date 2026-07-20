import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/job/effect/effect as job_effect
import glot_backend/job/effect/log/algebra as job_log_algebra
import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/program_types
import glot_core/admin/job_log_dto
import glot_core/job_log_model
import youid/uuid.{type Uuid}

pub fn list(
  request: job_log_dto.ListJobLogsRequest,
) -> program_types.Program(List(job_log_model.JobLog)) {
  program_types.Impure(
    program_types.DbEffect(list_effect(request, program_types.Pure)),
  )
}

pub fn get(
  id: Uuid,
) -> program_types.Program(option.Option(job_log_model.JobLog)) {
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
  job_effect.log(job_log_algebra.DeleteJobLogBefore(before: before, next: next))
}

fn list_effect(
  request: job_log_dto.ListJobLogsRequest,
  next: fn(List(job_log_model.JobLog)) -> next,
) -> program_types.DbEffect(next) {
  job_effect.log(job_log_algebra.ListJobLogs(request: request, next: next))
}

fn get_effect(
  id: Uuid,
  next: fn(option.Option(job_log_model.JobLog)) -> next,
) -> program_types.DbEffect(next) {
  job_effect.log(job_log_algebra.GetJobLog(id: id, next: next))
}
