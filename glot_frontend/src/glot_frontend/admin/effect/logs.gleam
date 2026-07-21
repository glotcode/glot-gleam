import glot_core/admin/api_log_dto
import glot_core/admin/run_log_dto
import glot_frontend/api/response

pub type Command(msg) {
  GetApiLogs(
    api_log_dto.ListApiLogsRequest,
    fn(response.Response(api_log_dto.ListApiLogsResponse)) -> msg,
  )
  GetApiLog(
    api_log_dto.GetApiLogRequest,
    fn(response.Response(api_log_dto.GetApiLogResponse)) -> msg,
  )
  GetRunLogs(
    run_log_dto.ListRunLogsRequest,
    fn(response.Response(run_log_dto.ListRunLogsResponse)) -> msg,
  )
  GetRunLog(
    run_log_dto.GetRunLogRequest,
    fn(response.Response(run_log_dto.GetRunLogResponse)) -> msg,
  )
}

pub fn map(command: Command(a), transform: fn(a) -> b) -> Command(b) {
  case command {
    GetApiLogs(request, complete) ->
      GetApiLogs(request, fn(result) { transform(complete(result)) })
    GetApiLog(request, complete) ->
      GetApiLog(request, fn(result) { transform(complete(result)) })
    GetRunLogs(request, complete) ->
      GetRunLogs(request, fn(result) { transform(complete(result)) })
    GetRunLog(request, complete) ->
      GetRunLog(request, fn(result) { transform(complete(result)) })
  }
}
