import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/program_types
import glot_backend/effect/error
import glot_backend/effect/job/job
import glot_backend/job as job_type
import youid/uuid.{type Uuid}

pub fn db_get_next_job(
  now: Timestamp,
  pending_status: job_type.Status,
  running_status: job_type.Status,
) -> program_types.Program(option.Option(job_type.Job)) {
  program_types.Impure(
    program_types.JobEffect(job.GetNextJob(
      now: now,
      pending_status: pending_status,
      running_status: running_status,
      next: program_types.Pure,
    )),
  )
}

pub fn insert(job job_value: job_type.Job) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.JobEffect(job.InsertJob(job_value, command_next)),
  )
}

pub fn mark_done(
  id id: Uuid,
  completed_at completed_at: Timestamp,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.JobEffect(job.MarkJobDone(id, completed_at, command_next)),
  )
}

pub fn reschedule(
  id id: Uuid,
  run_at run_at: Timestamp,
  last_error last_error: option.Option(String),
  updated_at updated_at: Timestamp,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.JobEffect(job.RescheduleJob(
      id: id,
      run_at: run_at,
      last_error: last_error,
      updated_at: updated_at,
      next: command_next,
    )),
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
