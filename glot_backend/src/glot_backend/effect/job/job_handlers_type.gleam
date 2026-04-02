import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/job
import youid/uuid.{type Uuid}

pub type JobHandlers {
  JobHandlers(
    get_next_job: fn(Timestamp, job.Status, job.Status) ->
      Result(option.Option(job.Job), error.DbQueryError),
    insert_job: fn(job.Job) -> Result(Nil, error.DbCommandError),
    mark_job_done: fn(Uuid, Timestamp) -> Result(Nil, error.DbCommandError),
    reschedule_job: fn(
      Uuid,
      Timestamp,
      option.Option(String),
      Timestamp,
    ) -> Result(Nil, error.DbCommandError),
  )
}
