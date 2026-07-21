import gleam/json
import glot_core/admin/job_dto
import glot_core/admin/job_log_dto
import glot_core/admin/periodic_job_dto
import glot_core/admin_action
import glot_frontend/api/request
import glot_frontend/api/response
import lustre/effect

pub fn get_admin_periodic_jobs(
  to_msg: fn(response.Response(periodic_job_dto.ListPeriodicJobsResponse)) ->
    msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminPeriodicJobsAction, Nil)

  request.send_admin(
    req,
    fn(_) { json.null() },
    periodic_job_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_periodic_job(
  request: periodic_job_dto.GetPeriodicJobRequest,
  to_msg: fn(response.Response(periodic_job_dto.GetPeriodicJobResponse)) -> msg,
) -> effect.Effect(msg) {
  let req =
    request.AdminRequest(admin_action.GetAdminPeriodicJobAction, request)

  request.send_admin(
    req,
    periodic_job_dto.encode_get_request,
    periodic_job_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn update_admin_periodic_job(
  request: periodic_job_dto.UpdatePeriodicJobRequest,
  to_msg: fn(response.Response(periodic_job_dto.UpdatePeriodicJobResponse)) ->
    msg,
) -> effect.Effect(msg) {
  let req =
    request.AdminRequest(admin_action.UpdateAdminPeriodicJobAction, request)

  request.send_admin(
    req,
    periodic_job_dto.encode_update_request,
    periodic_job_dto.update_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_jobs(
  request: job_dto.ListJobsRequest,
  to_msg: fn(response.Response(job_dto.ListJobsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminJobsAction, request)

  request.send_admin(
    req,
    job_dto.encode_list_request,
    job_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_job(
  request: job_dto.GetJobRequest,
  to_msg: fn(response.Response(job_dto.GetJobResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminJobAction, request)

  request.send_admin(
    req,
    job_dto.encode_get_request,
    job_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn create_admin_job(
  request: job_dto.CreateJobRequest,
  to_msg: fn(response.Response(job_dto.GetJobResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.CreateAdminJobAction, request)

  request.send_admin(
    req,
    job_dto.encode_create_request,
    job_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_job_logs(
  request: job_log_dto.ListJobLogsRequest,
  to_msg: fn(response.Response(job_log_dto.ListJobLogsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminJobLogsAction, request)

  request.send_admin(
    req,
    job_log_dto.encode_list_request,
    job_log_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_job_log(
  request: job_log_dto.GetJobLogRequest,
  to_msg: fn(response.Response(job_log_dto.GetJobLogResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminJobLogAction, request)

  request.send_admin(
    req,
    job_log_dto.encode_get_request,
    job_log_dto.get_response_decoder(),
    to_msg,
  )
}
