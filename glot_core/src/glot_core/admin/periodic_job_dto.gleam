import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/helpers/timestamp_helpers
import glot_core/helpers/uuid_helpers
import glot_core/job/job_model
import glot_core/periodic_job/periodic_job_model
import youid/uuid

pub type PeriodicJobResponse {
  PeriodicJobResponse(
    id: uuid.Uuid,
    job_type: String,
    payload: option.Option(String),
    interval_seconds: Int,
    enabled: Bool,
    next_run_at: Timestamp,
    last_enqueued_at: option.Option(Timestamp),
    last_enqueue_error: option.Option(String),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub type ListPeriodicJobsResponse {
  ListPeriodicJobsResponse(periodic_jobs: List(PeriodicJobResponse))
}

pub type GetPeriodicJobRequest {
  GetPeriodicJobRequest(id: uuid.Uuid)
}

pub type GetPeriodicJobResponse {
  GetPeriodicJobResponse(periodic_job: PeriodicJobResponse)
}

pub type UpdatePeriodicJobRequest {
  UpdatePeriodicJobRequest(
    id: uuid.Uuid,
    payload: option.Option(String),
    interval_seconds: Int,
    enabled: Bool,
    next_run_at: Timestamp,
  )
}

pub type UpdatePeriodicJobResponse {
  UpdatePeriodicJobResponse(periodic_job: PeriodicJobResponse)
}

pub fn list_response_decoder() -> decode.Decoder(ListPeriodicJobsResponse) {
  use periodic_jobs <- decode.field(
    "periodicJobs",
    decode.list(periodic_job_decoder()),
  )
  decode.success(ListPeriodicJobsResponse(periodic_jobs: periodic_jobs))
}

pub fn encode_list_response(response: ListPeriodicJobsResponse) -> json.Json {
  json.object([
    #(
      "periodicJobs",
      json.array(response.periodic_jobs, encode_periodic_job_response),
    ),
  ])
}

pub fn get_request_decoder() -> decode.Decoder(GetPeriodicJobRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  decode.success(GetPeriodicJobRequest(id: id))
}

pub fn encode_get_request(request: GetPeriodicJobRequest) -> json.Json {
  json.object([#("id", json.string(uuid.to_string(request.id)))])
}

pub fn get_response_decoder() -> decode.Decoder(GetPeriodicJobResponse) {
  use periodic_job <- decode.field("periodicJob", periodic_job_decoder())
  decode.success(GetPeriodicJobResponse(periodic_job: periodic_job))
}

pub fn encode_get_response(response: GetPeriodicJobResponse) -> json.Json {
  json.object([
    #("periodicJob", encode_periodic_job_response(response.periodic_job)),
  ])
}

pub fn update_request_decoder() -> decode.Decoder(UpdatePeriodicJobRequest) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use payload <- decode.field("payload", decode.optional(decode.string))
  use interval_seconds <- decode.field("intervalSeconds", decode.int)
  use enabled <- decode.field("enabled", decode.bool)
  use next_run_at <- decode.field("nextRunAt", timestamp_helpers.decoder())
  decode.success(UpdatePeriodicJobRequest(
    id: id,
    payload: payload,
    interval_seconds: interval_seconds,
    enabled: enabled,
    next_run_at: next_run_at,
  ))
}

pub fn encode_update_request(request: UpdatePeriodicJobRequest) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(request.id))),
    #("payload", json.nullable(request.payload, json.string)),
    #("intervalSeconds", json.int(request.interval_seconds)),
    #("enabled", json.bool(request.enabled)),
    #("nextRunAt", timestamp_helpers.encode(request.next_run_at)),
  ])
}

pub fn update_response_decoder() -> decode.Decoder(UpdatePeriodicJobResponse) {
  use periodic_job <- decode.field("periodicJob", periodic_job_decoder())
  decode.success(UpdatePeriodicJobResponse(periodic_job: periodic_job))
}

pub fn encode_update_response(response: UpdatePeriodicJobResponse) -> json.Json {
  json.object([
    #("periodicJob", encode_periodic_job_response(response.periodic_job)),
  ])
}

pub fn from_periodic_jobs(
  periodic_jobs: List(periodic_job_model.PeriodicJob),
) -> ListPeriodicJobsResponse {
  ListPeriodicJobsResponse(periodic_jobs: list.map(
    periodic_jobs,
    from_periodic_job,
  ))
}

pub fn from_updated_periodic_job(
  periodic_job: periodic_job_model.PeriodicJob,
) -> UpdatePeriodicJobResponse {
  UpdatePeriodicJobResponse(periodic_job: from_periodic_job(periodic_job))
}

pub fn from_periodic_job_detail(
  periodic_job: periodic_job_model.PeriodicJob,
) -> GetPeriodicJobResponse {
  GetPeriodicJobResponse(periodic_job: from_periodic_job(periodic_job))
}

fn from_periodic_job(
  periodic_job: periodic_job_model.PeriodicJob,
) -> PeriodicJobResponse {
  PeriodicJobResponse(
    id: periodic_job.id,
    job_type: job_model.job_type_to_string(periodic_job.job_type),
    payload: periodic_job.payload,
    interval_seconds: periodic_job.interval_seconds,
    enabled: periodic_job.enabled,
    next_run_at: periodic_job.next_run_at,
    last_enqueued_at: periodic_job.last_enqueued_at,
    last_enqueue_error: periodic_job.last_enqueue_error,
    created_at: periodic_job.created_at,
    updated_at: periodic_job.updated_at,
  )
}

fn periodic_job_decoder() -> decode.Decoder(PeriodicJobResponse) {
  use id <- decode.field("id", uuid_helpers.decoder())
  use job_type <- decode.field("jobType", decode.string)
  use payload <- decode.field("payload", decode.optional(decode.string))
  use interval_seconds <- decode.field("intervalSeconds", decode.int)
  use enabled <- decode.field("enabled", decode.bool)
  use next_run_at <- decode.field("nextRunAt", timestamp_helpers.decoder())
  use last_enqueued_at <- decode.field(
    "lastEnqueuedAt",
    decode.optional(timestamp_helpers.decoder()),
  )
  use last_enqueue_error <- decode.field(
    "lastEnqueueError",
    decode.optional(decode.string),
  )
  use created_at <- decode.field("createdAt", timestamp_helpers.decoder())
  use updated_at <- decode.field("updatedAt", timestamp_helpers.decoder())

  decode.success(PeriodicJobResponse(
    id: id,
    job_type: job_type,
    payload: payload,
    interval_seconds: interval_seconds,
    enabled: enabled,
    next_run_at: next_run_at,
    last_enqueued_at: last_enqueued_at,
    last_enqueue_error: last_enqueue_error,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn encode_periodic_job_response(periodic_job: PeriodicJobResponse) -> json.Json {
  json.object([
    #("id", json.string(uuid.to_string(periodic_job.id))),
    #("jobType", json.string(periodic_job.job_type)),
    #("payload", json.nullable(periodic_job.payload, json.string)),
    #("intervalSeconds", json.int(periodic_job.interval_seconds)),
    #("enabled", json.bool(periodic_job.enabled)),
    #("nextRunAt", timestamp_helpers.encode(periodic_job.next_run_at)),
    #(
      "lastEnqueuedAt",
      json.nullable(periodic_job.last_enqueued_at, timestamp_helpers.encode),
    ),
    #(
      "lastEnqueueError",
      json.nullable(periodic_job.last_enqueue_error, json.string),
    ),
    #("createdAt", timestamp_helpers.encode(periodic_job.created_at)),
    #("updatedAt", timestamp_helpers.encode(periodic_job.updated_at)),
  ])
}
