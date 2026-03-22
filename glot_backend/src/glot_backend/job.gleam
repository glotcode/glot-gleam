import gleam/json
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_backend/email_message
import youid/uuid.{type Uuid}

pub type JobType {
  SendEmailJob
}

pub fn job_type_to_string(job_type: JobType) -> String {
  case job_type {
    SendEmailJob -> "send_email"
  }
}

pub fn job_type_from_string(value: String) -> Result(JobType, String) {
  case value {
    "send_email" -> Ok(SendEmailJob)
    _ -> Error("Invalid job type: " <> value)
  }
}

pub type Status {
  Pending
  Running
  Done
  Failed
}

pub fn status_to_string(status: Status) -> String {
  case status {
    Pending -> "pending"
    Running -> "running"
    Done -> "done"
    Failed -> "failed"
  }
}

pub fn status_from_string(value: String) -> Result(Status, String) {
  case value {
    "pending" -> Ok(Pending)
    "running" -> Ok(Running)
    "done" -> Ok(Done)
    "failed" -> Ok(Failed)
    _ -> Error("Invalid job status: " <> value)
  }
}

pub type Job {
  Job(
    id: Uuid,
    job_type: JobType,
    payload: String,
    status: Status,
    attempts: Int,
    max_attempts: Int,
    timeout_seconds: Int,
    run_at: Timestamp,
    started_at: Option(Timestamp),
    completed_at: Option(Timestamp),
    last_error: Option(String),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

fn new(id: Uuid, job_type: JobType, now: Timestamp, payload: String) -> Job {
  // TODO: we could make JobType a union type and deserialize the payload here
  Job(
    id: id,
    job_type: job_type,
    payload: payload,
    status: Pending,
    attempts: 0,
    max_attempts: 3,
    timeout_seconds: 120,
    run_at: now,
    started_at: option.None,
    completed_at: option.None,
    last_error: option.None,
    created_at: now,
    updated_at: now,
  )
}

pub fn send_email_job(
  id: Uuid,
  now: Timestamp,
  email: email_message.EmailMessage,
) -> Job {
  new(
    id,
    SendEmailJob,
    now,
    email
      |> email_message.encode_message
      |> json.to_string,
  )
}
