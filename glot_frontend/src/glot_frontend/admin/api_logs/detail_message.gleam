import glot_core/admin/api_log_dto
import glot_frontend/api/response as api_response

pub type Msg {
  LogLoaded(api_response.Response(api_log_dto.GetApiLogResponse))
}
