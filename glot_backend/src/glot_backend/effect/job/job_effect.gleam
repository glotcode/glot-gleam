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
    program_types.DbEffect(get_next_job_effect(
      now,
      pending_status,
      program_types.Pure,
    )),
  )
}

pub fn create_job(job j: job_model.Job) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_job_effect(j, command_next)),
  )
}

pub fn update_job(job j: job_model.Job) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_job_effect(j, command_next)),
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

pub fn get_next_job_tx(
  now: Timestamp,
  pending_status: job_model.Status,
) -> program_types.TransactionProgram(option.Option(job_model.Job)) {
  program_types.TxImpure(get_next_job_effect(
    now,
    pending_status,
    program_types.TxPure,
  ))
}

pub fn create_job_tx(
  job j: job_model.Job,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_job_effect(j, tx_command_next))
}

pub fn update_job_tx(
  job j: job_model.Job,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_job_effect(j, tx_command_next))
}

fn tx_command_next(
  result: Result(Nil, error.DbCommandError),
) -> program_types.TransactionProgram(Nil) {
  case result {
    Ok(_) -> program_types.TxPure(Nil)
    Error(err) -> program_types.TxFail(error.CommandError(err))
  }
}

fn get_next_job_effect(
  now: Timestamp,
  pending_status: job_model.Status,
  next: fn(option.Option(job_model.Job)) -> next,
) -> program_types.DbEffect(next) {
  program_types.JobEffect(job_algebra.GetNextJob(
    now:,
    pending_status:,
    next: next,
  ))
}

fn create_job_effect(
  job: job_model.Job,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.JobEffect(job_algebra.CreateJob(job, next))
}

fn update_job_effect(
  job: job_model.Job,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.JobEffect(job_algebra.UpdateJob(job, next))
}
