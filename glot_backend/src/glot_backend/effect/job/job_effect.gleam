import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/effect/program_types
import glot_backend/effect/job/job
import glot_backend/job as job_type

pub fn db_get_next_job(
  now: Timestamp,
  pending_status: job_type.Status,
) -> program_types.Program(option.Option(job_type.Job)) {
  program_types.Impure(
    program_types.JobEffect(job.GetNextJob(
      now: now,
      pending_status: pending_status,
      next: program_types.Pure,
    )),
  )
}

pub fn insert(job j: job_type.Job) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.JobEffect(job.InsertJob(j, command_next)),
  )
}

pub fn update(job j: job_type.Job) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.JobEffect(job.UpdateJob(j, command_next)),
  )
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}
