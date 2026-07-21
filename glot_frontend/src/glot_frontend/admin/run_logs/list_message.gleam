import glot_core/admin/run_log_dto
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  LogsLoaded(Generation, api_response.Response(run_log_dto.ListRunLogsResponse))
  OutcomeFilterSelected(run_log_dto.RunLogOutcomeFilter)
  RequestIdFilterChanged(String)
  SessionIdFilterChanged(String)
  UserIdFilterChanged(String)
  LanguageFilterChanged(String)
  ApplyFilters
  NextPageClicked
  PreviousPageClicked
}
