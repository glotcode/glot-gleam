import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/effect/error
import glot_backend/effect/job/job_algebra
import glot_backend/effect/program_types
import glot_core/job/job_model
import youid/uuid.{type Uuid}

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

pub fn get_job_by_id(
  id id: Uuid,
) -> program_types.Program(option.Option(job_model.Job)) {
  program_types.Impure(
    program_types.DbEffect(get_job_by_id_effect(id, program_types.Pure)),
  )
}

pub fn update_job(job j: job_model.Job) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_job_effect(j, command_next)),
  )
}

pub fn delete_job(id id: Uuid) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_job_effect(id, command_next)),
  )
}

pub fn delete_before(
  before: Timestamp,
  statuses: List(job_model.Status),
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(delete_before_effect(
      before,
      statuses,
      command_next,
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

pub fn get_job_by_id_tx(
  id id: Uuid,
) -> program_types.TransactionProgram(option.Option(job_model.Job)) {
  program_types.TxImpure(get_job_by_id_effect(id, program_types.TxPure))
}

pub fn update_job_tx(
  job j: job_model.Job,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_job_effect(j, tx_command_next))
}

pub fn delete_job_tx(id id: Uuid) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_job_effect(id, tx_command_next))
}

pub fn delete_before_tx(
  before: Timestamp,
  statuses: List(job_model.Status),
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(delete_before_effect(
    before,
    statuses,
    tx_command_next,
  ))
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

fn get_job_by_id_effect(
  id: Uuid,
  next: fn(option.Option(job_model.Job)) -> next,
) -> program_types.DbEffect(next) {
  program_types.JobEffect(job_algebra.GetJobById(id:, next: next))
}

fn update_job_effect(
  job: job_model.Job,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.JobEffect(job_algebra.UpdateJob(job, next))
}

fn delete_job_effect(
  id: Uuid,
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.JobEffect(job_algebra.DeleteJob(id, next))
}

fn delete_before_effect(
  before: Timestamp,
  statuses: List(job_model.Status),
  next: fn(Result(Nil, error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  program_types.JobEffect(job_algebra.DeleteBefore(
    before: before,
    statuses: statuses,
    next: next,
  ))
}
