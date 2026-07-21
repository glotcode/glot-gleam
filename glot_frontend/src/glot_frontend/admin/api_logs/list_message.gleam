import glot_core/admin/api_log_dto
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  LogsLoaded(Generation, api_response.Response(api_log_dto.ListApiLogsResponse))
  ErrorFilterSelected(api_log_dto.ApiLogErrorFilter)
  RequestIdFilterChanged(String)
  ApplyFilters
  NextPageClicked
  PreviousPageClicked
}
