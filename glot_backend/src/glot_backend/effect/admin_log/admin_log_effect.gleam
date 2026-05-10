import gleam/option
import glot_backend/effect/admin_log/admin_log_algebra
import glot_backend/effect/program_types
import glot_core/admin/api_log_dto
import glot_core/admin/job_log_dto
import glot_core/admin/run_log_dto
import glot_core/api_log_model
import glot_core/job_log_model
import glot_core/run_log_model
import youid/uuid.{type Uuid}

pub fn list_api_logs(
  request: api_log_dto.ListApiLogsRequest,
) -> program_types.Program(List(api_log_model.ApiLogSummary)) {
  program_types.Impure(
    program_types.DbEffect(list_api_logs_effect(request, program_types.Pure)),
  )
}

pub fn get_api_log(
  id: Uuid,
) -> program_types.Program(option.Option(api_log_model.ApiLogDetail)) {
  program_types.Impure(
    program_types.DbEffect(get_api_log_effect(id, program_types.Pure)),
  )
}

pub fn list_run_logs(
  request: run_log_dto.ListRunLogsRequest,
) -> program_types.Program(List(run_log_model.RunLog)) {
  program_types.Impure(
    program_types.DbEffect(list_run_logs_effect(request, program_types.Pure)),
  )
}

pub fn get_run_log(
  id: Uuid,
) -> program_types.Program(option.Option(run_log_model.RunLog)) {
  program_types.Impure(
    program_types.DbEffect(get_run_log_effect(id, program_types.Pure)),
  )
}

pub fn list_job_logs(
  request: job_log_dto.ListJobLogsRequest,
) -> program_types.Program(List(job_log_model.JobLog)) {
  program_types.Impure(
    program_types.DbEffect(list_job_logs_effect(request, program_types.Pure)),
  )
}

pub fn get_job_log(
  id: Uuid,
) -> program_types.Program(option.Option(job_log_model.JobLog)) {
  program_types.Impure(
    program_types.DbEffect(get_job_log_effect(id, program_types.Pure)),
  )
}

fn list_api_logs_effect(
  request: api_log_dto.ListApiLogsRequest,
  next: fn(List(api_log_model.ApiLogSummary)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AdminLogEffect(admin_log_algebra.ListApiLogs(
    request: request,
    next: next,
  ))
}

fn get_api_log_effect(
  id: Uuid,
  next: fn(option.Option(api_log_model.ApiLogDetail)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AdminLogEffect(admin_log_algebra.GetApiLog(
    id: id,
    next: next,
  ))
}

fn list_run_logs_effect(
  request: run_log_dto.ListRunLogsRequest,
  next: fn(List(run_log_model.RunLog)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AdminLogEffect(admin_log_algebra.ListRunLogs(
    request: request,
    next: next,
  ))
}

fn get_run_log_effect(
  id: Uuid,
  next: fn(option.Option(run_log_model.RunLog)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AdminLogEffect(admin_log_algebra.GetRunLog(id: id, next: next))
}

fn list_job_logs_effect(
  request: job_log_dto.ListJobLogsRequest,
  next: fn(List(job_log_model.JobLog)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AdminLogEffect(admin_log_algebra.ListJobLogs(
    request: request,
    next: next,
  ))
}

fn get_job_log_effect(
  id: Uuid,
  next: fn(option.Option(job_log_model.JobLog)) -> next,
) -> program_types.DbEffect(next) {
  program_types.AdminLogEffect(admin_log_algebra.GetJobLog(id: id, next: next))
}
