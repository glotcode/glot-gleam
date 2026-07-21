import glot_core/admin/job_log_dto
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  LogsLoaded(Generation, api_response.Response(job_log_dto.ListJobLogsResponse))
  ErrorFilterSelected(job_log_dto.JobLogErrorFilter)
  RequestIdFilterChanged(String)
  JobIdFilterChanged(String)
  ApplyFilters
  NextPageClicked
  PreviousPageClicked
}
