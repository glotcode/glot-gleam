import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/job_dto
import glot_core/admin/job_log_dto
import glot_frontend/admin/local_datetime.{type LocalDateTime, type ParseResult}
import glot_frontend/admin/request_generation.{type Generation}
import glot_frontend/api/response as api_response

pub type Msg {
  JobLoaded(api_response.Response(job_dto.GetJobResponse))
  JobLogsLoaded(
    Generation,
    api_response.Response(job_log_dto.ListJobLogsResponse),
  )
  NextLogsPageClicked
  PreviousLogsPageClicked
  OpenCreateJobClicked
  OpenCreateJobAt(Timestamp)
  OpenCreateJobWithLocalDateTime(LocalDateTime)
  CreateJobDialogClosed
  CreateJobCancelled
  CreateJobSubmitted
  CreateJobRunAtParsed(Generation, ParseResult)
  CreateJobFinished(Generation, api_response.Response(job_dto.GetJobResponse))
  CreateJobPayloadChanged(String)
  CreateJobMaxAttemptsChanged(String)
  CreateJobTimeoutSecondsChanged(String)
  CreateJobRunDateChanged(String)
  CreateJobRunTimeChanged(String)
}
