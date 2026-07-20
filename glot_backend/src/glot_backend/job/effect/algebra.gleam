import glot_backend/job/effect/job/algebra as job_algebra
import glot_backend/job/effect/log/algebra as log_algebra
import glot_backend/job/effect/periodic/algebra as periodic_algebra
import glot_backend/job/effect/type_policy/algebra as type_policy_algebra

pub type Effect(next) {
  Job(job_algebra.JobEffect(next))
  Log(log_algebra.JobLogEffect(next))
  Periodic(periodic_algebra.PeriodicJobEffect(next))
  TypePolicy(type_policy_algebra.JobTypePolicyEffect(next))
}

pub type EffectName {
  JobName(job_algebra.EffectName)
  LogName(log_algebra.EffectName)
  PeriodicName(periodic_algebra.EffectName)
  TypePolicyName(type_policy_algebra.EffectName)
}

pub fn map(effect: Effect(a), transform: fn(a) -> b) -> Effect(b) {
  case effect {
    Job(effect) -> Job(job_algebra.map(effect, transform))
    Log(effect) -> Log(log_algebra.map(effect, transform))
    Periodic(effect) -> Periodic(periodic_algebra.map(effect, transform))
    TypePolicy(effect) -> TypePolicy(type_policy_algebra.map(effect, transform))
  }
}

pub fn effect_name_to_string(name: EffectName) -> String {
  case name {
    JobName(name) -> job_algebra.effect_name_to_string(name)
    LogName(name) -> log_algebra.effect_name_to_string(name)
    PeriodicName(name) -> periodic_algebra.effect_name_to_string(name)
    TypePolicyName(name) -> type_policy_algebra.effect_name_to_string(name)
  }
}

pub fn effect_name_to_family(name: EffectName) -> String {
  case name {
    JobName(_) -> "job"
    LogName(_) -> "job_log"
    PeriodicName(_) -> "periodic_job"
    TypePolicyName(_) -> "job_type_policy"
  }
}
