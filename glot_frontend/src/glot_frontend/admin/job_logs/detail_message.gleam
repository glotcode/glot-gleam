import glot_core/admin/job_log_dto
import glot_frontend/api/response as api_response

pub type Msg {
  LogLoaded(api_response.Response(job_log_dto.GetJobLogResponse))
}
