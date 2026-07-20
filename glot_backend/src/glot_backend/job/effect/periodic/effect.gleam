import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/job/effect/effect as job_effect
import glot_backend/job/effect/periodic/algebra as periodic_job_algebra
import glot_backend/system/effect/error
import glot_backend/system/effect/error/db_error
import glot_backend/system/effect/program_types
import glot_core/periodic_job/periodic_job_model
import youid/uuid

pub fn list_periodic_jobs() -> program_types.Program(
  List(periodic_job_model.PeriodicJob),
) {
  program_types.Impure(
    program_types.DbEffect(list_periodic_jobs_effect(program_types.Pure)),
  )
}

pub fn get_next_periodic_job(
  now: Timestamp,
) -> program_types.Program(option.Option(periodic_job_model.PeriodicJob)) {
  program_types.Impure(
    program_types.DbEffect(get_next_periodic_job_effect(now, program_types.Pure)),
  )
}

pub fn get_periodic_job_by_id(
  id: uuid.Uuid,
) -> program_types.Program(option.Option(periodic_job_model.PeriodicJob)) {
  program_types.Impure(
    program_types.DbEffect(get_periodic_job_by_id_effect(id, program_types.Pure)),
  )
}

pub fn create_periodic_job(
  periodic_job periodic_job: periodic_job_model.PeriodicJob,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(create_periodic_job_effect(
      periodic_job,
      command_next,
    )),
  )
}

pub fn update_periodic_job(
  periodic_job periodic_job: periodic_job_model.PeriodicJob,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(update_periodic_job_effect(
      periodic_job,
      command_next,
    )),
  )
}

fn command_next(
  result: Result(Nil, db_error.DbCommandError),
) -> program_types.Program(Nil) {
  case result {
    Ok(_) -> program_types.Pure(Nil)
    Error(err) -> program_types.Fail(error.database_command_error(err))
  }
}

pub fn get_next_periodic_job_tx(
  now: Timestamp,
) -> program_types.TransactionProgram(
  option.Option(periodic_job_model.PeriodicJob),
) {
  program_types.TxImpure(get_next_periodic_job_effect(now, program_types.TxPure))
}

pub fn create_periodic_job_tx(
  periodic_job periodic_job: periodic_job_model.PeriodicJob,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(create_periodic_job_effect(
    periodic_job,
    tx_command_next,
  ))
}

pub fn update_periodic_job_tx(
  periodic_job periodic_job: periodic_job_model.PeriodicJob,
) -> program_types.TransactionProgram(Nil) {
  program_types.TxImpure(update_periodic_job_effect(
    periodic_job,
    tx_command_next,
  ))
}

fn tx_command_next(
  result: Result(Nil, db_error.DbCommandError),
) -> program_types.TransactionProgram(Nil) {
  case result {
    Ok(_) -> program_types.TxPure(Nil)
    Error(err) -> program_types.TxFail(error.database_command_error(err))
  }
}

fn list_periodic_jobs_effect(
  next: fn(List(periodic_job_model.PeriodicJob)) -> next,
) -> program_types.DbEffect(next) {
  job_effect.periodic(periodic_job_algebra.ListPeriodicJobs(next: next))
}

fn get_next_periodic_job_effect(
  now: Timestamp,
  next: fn(option.Option(periodic_job_model.PeriodicJob)) -> next,
) -> program_types.DbEffect(next) {
  job_effect.periodic(periodic_job_algebra.GetNextPeriodicJob(
    now: now,
    next: next,
  ))
}

fn get_periodic_job_by_id_effect(
  id: uuid.Uuid,
  next: fn(option.Option(periodic_job_model.PeriodicJob)) -> next,
) -> program_types.DbEffect(next) {
  job_effect.periodic(periodic_job_algebra.GetPeriodicJobById(
    id: id,
    next: next,
  ))
}

fn create_periodic_job_effect(
  periodic_job: periodic_job_model.PeriodicJob,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  job_effect.periodic(periodic_job_algebra.CreatePeriodicJob(periodic_job, next))
}

fn update_periodic_job_effect(
  periodic_job: periodic_job_model.PeriodicJob,
  next: fn(Result(Nil, db_error.DbCommandError)) -> next,
) -> program_types.DbEffect(next) {
  job_effect.periodic(periodic_job_algebra.UpdatePeriodicJob(periodic_job, next))
}
