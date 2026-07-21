import glot_core/admin/job_dto
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  JobsLoaded(Generation, api_response.Response(job_dto.ListJobsResponse))
  StatusFilterSelected(job_dto.StatusFilter)
  JobTypeFilterSelected(String)
  NextPageClicked
  PreviousPageClicked
}
