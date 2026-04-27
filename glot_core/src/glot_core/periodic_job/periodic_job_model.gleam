import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/job/job_model
import youid/uuid.{type Uuid}

pub type PeriodicJob {
  PeriodicJob(
    id: Uuid,
    job_type: job_model.JobType,
    payload: Option(String),
    interval_seconds: Int,
    enabled: Bool,
    next_run_at: Timestamp,
    last_enqueued_at: Option(Timestamp),
    last_enqueue_error: Option(String),
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub fn enqueued(periodic_job: PeriodicJob, now: Timestamp) -> PeriodicJob {
  PeriodicJob(
    ..periodic_job,
    next_run_at: add_seconds(periodic_job.next_run_at, periodic_job.interval_seconds),
    last_enqueued_at: option.Some(now),
    last_enqueue_error: option.None,
    updated_at: now,
  )
}

pub fn enqueue_failed(
  periodic_job: PeriodicJob,
  error_message: String,
  now: Timestamp,
) -> PeriodicJob {
  PeriodicJob(
    ..periodic_job,
    last_enqueue_error: option.Some(error_message),
    updated_at: now,
  )
}

fn add_seconds(ts: Timestamp, seconds_to_add: Int) -> Timestamp {
  let #(seconds, nanos) = timestamp.to_unix_seconds_and_nanoseconds(ts)
  timestamp.from_unix_seconds_and_nanoseconds(seconds + seconds_to_add, nanos)
}
