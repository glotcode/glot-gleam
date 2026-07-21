import glot_core/admin/periodic_job_dto
import glot_frontend/api/response as api_response

pub type Msg {
  PeriodicJobsLoaded(
    api_response.Response(periodic_job_dto.ListPeriodicJobsResponse),
  )
}
