import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import glot_core/job/job_model

pub type JobTypePolicyEffect(next) {
  ListJobTypePolicies(next: fn(List(job_model.JobTypePolicy)) -> next)
  GetJobTypePolicyByJobType(
    job_type: job_model.JobType,
    next: fn(Option(job_model.JobTypePolicy)) -> next,
  )
  UpsertJobTypePolicy(
    policy: job_model.JobTypePolicy,
    now: Timestamp,
    next: fn(Nil) -> next,
  )
}

pub fn map(
  effect: JobTypePolicyEffect(a),
  f: fn(a) -> b,
) -> JobTypePolicyEffect(b) {
  case effect {
    ListJobTypePolicies(next:) ->
      ListJobTypePolicies(next: fn(value) { f(next(value)) })
    GetJobTypePolicyByJobType(job_type:, next:) ->
      GetJobTypePolicyByJobType(job_type: job_type, next: fn(value) {
        f(next(value))
      })
    UpsertJobTypePolicy(policy:, now:, next:) ->
      UpsertJobTypePolicy(policy: policy, now: now, next: fn(value) {
        f(next(value))
      })
  }
}

pub type EffectName {
  ListJobTypePoliciesEffectName
  GetJobTypePolicyByJobTypeEffectName
  UpsertJobTypePolicyEffectName
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    ListJobTypePoliciesEffectName -> "list_job_type_policies"
    GetJobTypePolicyByJobTypeEffectName -> "get_job_type_policy_by_job_type"
    UpsertJobTypePolicyEffectName -> "upsert_job_type_policy"
  }
}
