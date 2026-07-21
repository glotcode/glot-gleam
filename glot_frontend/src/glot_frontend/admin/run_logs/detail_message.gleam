import glot_core/admin/run_log_dto
import glot_frontend/api/response as api_response

pub type Msg {
  LogLoaded(api_response.Response(run_log_dto.GetRunLogResponse))
}
