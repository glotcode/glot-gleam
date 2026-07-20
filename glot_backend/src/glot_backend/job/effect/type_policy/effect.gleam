import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_backend/job/effect/effect as job_effect
import glot_backend/job/effect/type_policy/algebra as job_type_policy_algebra
import glot_backend/system/effect/program_types
import glot_core/job/job_model

pub fn list_job_type_policies() -> program_types.Program(
  List(job_model.JobTypePolicy),
) {
  program_types.Impure(
    program_types.DbEffect(
      job_effect.type_policy(job_type_policy_algebra.ListJobTypePolicies(
        next: program_types.Pure,
      )),
    ),
  )
}

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
  job_effect.type_policy(job_type_policy_algebra.GetJobTypePolicyByJobType(
    job_type: job_type,
    next: next,
  ))
}

pub fn upsert_job_type_policy(
  policy: job_model.JobTypePolicy,
  now: Timestamp,
) -> program_types.Program(Nil) {
  program_types.Impure(
    program_types.DbEffect(
      job_effect.type_policy(job_type_policy_algebra.UpsertJobTypePolicy(
        policy: policy,
        now: now,
        next: program_types.Pure,
      )),
    ),
  )
}
