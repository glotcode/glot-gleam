import glot_core/admin/job_dto
import glot_core/admin/periodic_job_dto
import glot_frontend/admin/local_datetime.{type LocalDateTime, type ParseResult}
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  PeriodicJobLoaded(
    Generation,
    api_response.Response(periodic_job_dto.GetPeriodicJobResponse),
  )
  LoadedPeriodicJobFormatted(
    Generation,
    periodic_job_dto.PeriodicJobResponse,
    LocalDateTime,
  )
  PayloadChanged(String)
  IntervalSecondsChanged(String)
  EnabledToggled
  NextRunDateChanged(String)
  NextRunTimeChanged(String)
  ResetClicked
  SaveClicked
  NextRunAtParsed(Generation, ParseResult)
  SaveFinished(
    Generation,
    api_response.Response(periodic_job_dto.UpdatePeriodicJobResponse),
  )
  SavedPeriodicJobFormatted(
    Generation,
    periodic_job_dto.PeriodicJobResponse,
    LocalDateTime,
  )
  RecentJobsLoaded(Generation, api_response.Response(job_dto.ListJobsResponse))
}
