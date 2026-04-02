import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/effect_model
import glot_backend/effect/error
import glot_backend/effect/job/job
import glot_backend/job as job_type
import youid/uuid.{type Uuid}

pub fn db_get_next_job(
  now: Timestamp,
  pending_status: job_type.Status,
  running_status: job_type.Status,
) -> effect_model.Program(option.Option(job_type.Job)) {
  effect_model.Impure(
    effect_model.JobEffect(job.GetNextJob(
      now: now,
      pending_status: pending_status,
      running_status: running_status,
      next: effect_model.Pure,
    )),
  )
}

pub fn insert(job job_value: job_type.Job) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.JobEffect(job.InsertJob(job_value, command_next)),
  )
}

pub fn mark_done(
  id id: Uuid,
  completed_at completed_at: Timestamp,
) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.JobEffect(job.MarkJobDone(id, completed_at, command_next)),
  )
}

pub fn reschedule(
  id id: Uuid,
  run_at run_at: Timestamp,
  last_error last_error: option.Option(String),
  updated_at updated_at: Timestamp,
) -> effect_model.Program(Nil) {
  effect_model.Impure(
    effect_model.JobEffect(job.RescheduleJob(
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
) -> effect_model.Program(Nil) {
  case result {
    Ok(_) -> effect_model.Pure(Nil)
    Error(err) -> effect_model.Fail(error.CommandError(err))
  }
}
