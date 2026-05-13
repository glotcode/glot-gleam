import gleam/option
import glot_backend/effect/job_type_policy/job_type_policy_algebra
import glot_backend/effect/program_types
import glot_core/job/job_model

pub fn get_job_type_policy_by_job_type(
  job_type: job_model.JobType,
) -> program_types.Program(option.Option(job_model.JobTypePolicy)) {
  program_types.Impure(
    program_types.DbEffect(get_job_type_policy_by_job_type_effect(
      job_type,
      program_types.Pure,
    )),
  )
}

pub fn get_job_type_policy_by_job_type_tx(
  job_type: job_model.JobType,
) -> program_types.TransactionProgram(option.Option(job_model.JobTypePolicy)) {
  program_types.TxImpure(get_job_type_policy_by_job_type_effect(
    job_type,
    program_types.TxPure,
  ))
}

fn get_job_type_policy_by_job_type_effect(
  job_type: job_model.JobType,
  next: fn(option.Option(job_model.JobTypePolicy)) -> next,
) -> program_types.DbEffect(next) {
  program_types.JobTypePolicyEffect(
    job_type_policy_algebra.GetJobTypePolicyByJobType(
      job_type: job_type,
      next: next,
    ),
  )
}
