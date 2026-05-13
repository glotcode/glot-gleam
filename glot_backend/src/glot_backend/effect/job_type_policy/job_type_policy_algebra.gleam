import gleam/option.{type Option}
import glot_core/job/job_model

pub type JobTypePolicyEffect(next) {
  GetJobTypePolicyByJobType(
    job_type: job_model.JobType,
    next: fn(Option(job_model.JobTypePolicy)) -> next,
  )
}

pub fn map(
  effect: JobTypePolicyEffect(a),
  f: fn(a) -> b,
) -> JobTypePolicyEffect(b) {
  case effect {
    GetJobTypePolicyByJobType(job_type:, next:) ->
      GetJobTypePolicyByJobType(job_type: job_type, next: fn(value) {
        f(next(value))
      })
  }
}

pub type EffectName {
  GetJobTypePolicyByJobTypeEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    GetJobTypePolicyByJobTypeEffectName -> "get_job_type_policy_by_job_type"
  }
}
