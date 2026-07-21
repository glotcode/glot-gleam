import glot_core/admin/job_dto
import glot_core/admin/job_log_dto
import glot_core/admin/periodic_job_dto
import glot_frontend/api/response

pub type Command(msg) {
  GetPeriodicJobs(
    fn(response.Response(periodic_job_dto.ListPeriodicJobsResponse)) -> msg,
  )
  GetPeriodicJob(
    periodic_job_dto.GetPeriodicJobRequest,
    fn(response.Response(periodic_job_dto.GetPeriodicJobResponse)) -> msg,
  )
  UpdatePeriodicJob(
    periodic_job_dto.UpdatePeriodicJobRequest,
    fn(response.Response(periodic_job_dto.UpdatePeriodicJobResponse)) -> msg,
  )
  GetJobs(
    job_dto.ListJobsRequest,
    fn(response.Response(job_dto.ListJobsResponse)) -> msg,
  )
  GetJob(
    job_dto.GetJobRequest,
    fn(response.Response(job_dto.GetJobResponse)) -> msg,
  )
  CreateJob(
    job_dto.CreateJobRequest,
    fn(response.Response(job_dto.GetJobResponse)) -> msg,
  )
  GetJobLogs(
    job_log_dto.ListJobLogsRequest,
    fn(response.Response(job_log_dto.ListJobLogsResponse)) -> msg,
  )
  GetJobLog(
    job_log_dto.GetJobLogRequest,
    fn(response.Response(job_log_dto.GetJobLogResponse)) -> msg,
  )
}

pub fn map(command: Command(a), transform: fn(a) -> b) -> Command(b) {
  case command {
    GetPeriodicJobs(complete) ->
      GetPeriodicJobs(fn(result) { transform(complete(result)) })
    GetPeriodicJob(request, complete) ->
      GetPeriodicJob(request, fn(result) { transform(complete(result)) })
    UpdatePeriodicJob(request, complete) ->
      UpdatePeriodicJob(request, fn(result) { transform(complete(result)) })
    GetJobs(request, complete) ->
      GetJobs(request, fn(result) { transform(complete(result)) })
    GetJob(request, complete) ->
      GetJob(request, fn(result) { transform(complete(result)) })
    CreateJob(request, complete) ->
      CreateJob(request, fn(result) { transform(complete(result)) })
    GetJobLogs(request, complete) ->
      GetJobLogs(request, fn(result) { transform(complete(result)) })
    GetJobLog(request, complete) ->
      GetJobLog(request, fn(result) { transform(complete(result)) })
  }
}
