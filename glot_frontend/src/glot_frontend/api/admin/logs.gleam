import glot_core/admin/api_log_dto
import glot_core/admin/run_log_dto
import glot_core/admin_action
import glot_frontend/api/request
import glot_frontend/api/response
import lustre/effect

pub fn get_admin_api_logs(
  request: api_log_dto.ListApiLogsRequest,
  to_msg: fn(response.Response(api_log_dto.ListApiLogsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminApiLogsAction, request)

  request.send_admin(
    req,
    api_log_dto.encode_list_request,
    api_log_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_api_log(
  request: api_log_dto.GetApiLogRequest,
  to_msg: fn(response.Response(api_log_dto.GetApiLogResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminApiLogAction, request)

  request.send_admin(
    req,
    api_log_dto.encode_get_request,
    api_log_dto.get_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_run_logs(
  request: run_log_dto.ListRunLogsRequest,
  to_msg: fn(response.Response(run_log_dto.ListRunLogsResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminRunLogsAction, request)

  request.send_admin(
    req,
    run_log_dto.encode_list_request,
    run_log_dto.list_response_decoder(),
    to_msg,
  )
}

pub fn get_admin_run_log(
  request: run_log_dto.GetRunLogRequest,
  to_msg: fn(response.Response(run_log_dto.GetRunLogResponse)) -> msg,
) -> effect.Effect(msg) {
  let req = request.AdminRequest(admin_action.GetAdminRunLogAction, request)

  request.send_admin(
    req,
    run_log_dto.encode_get_request,
    run_log_dto.get_response_decoder(),
    to_msg,
  )
}
