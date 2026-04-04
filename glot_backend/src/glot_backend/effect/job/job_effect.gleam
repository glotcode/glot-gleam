import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/effect/job/job_algebra
import glot_backend/effect/program_types
import glot_core/job/job_model

pub fn get_next_job(
  now: Timestamp,
  pending_status: job_model.Status,
) -> program_types.Program(option.Option(job_model.Job)) {
  program_types.Impure(
    program_types.JobEffect(job_algebra.GetNextJob(
      now: now,
      pending_status: pending_status,
      next: program_types.Pure,
    )),
  )
}

pub fn create_job(job j: job_model.Job) -> program_types.Program(Nil) {
  program_types.Impure(program_types.JobEffect(job_algebra.CreateJob(j, command_next)))
}

pub fn update_job(job j: job_model.Job) -> program_types.Program(Nil) {
  program_types.Impure(program_types.JobEffect(job_algebra.UpdateJob(j, command_next)))
}

fn command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.CommandError(err))
  }
}
