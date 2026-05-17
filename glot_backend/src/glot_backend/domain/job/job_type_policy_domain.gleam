import glot_backend/effect/error
import glot_backend/effect/error/resource_error
import glot_backend/effect/job_type_policy/job_type_policy_effect
import glot_backend/effect/program
import glot_backend/effect/program_types
import glot_core/job/job_model

pub fn require_job_type_policy(
  job_type: job_model.JobType,
) -> program_types.Program(job_model.JobTypePolicy) {
  job_type_policy_effect.get_job_type_policy_by_job_type(job_type)
  |> program.require(error.resource(resource_error.JobTypePolicyNotFound))
}
