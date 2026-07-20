import glot_backend/job/effect/algebra
import glot_backend/job/effect/job/algebra as job_algebra
import glot_backend/job/effect/log/algebra as log_algebra
import glot_backend/job/effect/periodic/algebra as periodic_algebra
import glot_backend/job/effect/type_policy/algebra as type_policy_algebra
import glot_backend/system/effect/program_types

pub fn job(
  effect: job_algebra.JobEffect(next),
) -> program_types.DbEffect(next) {
  program_types.JobEffect(algebra.Job(effect))
}

pub fn log(
  effect: log_algebra.JobLogEffect(next),
) -> program_types.DbEffect(next) {
  program_types.JobEffect(algebra.Log(effect))
}

pub fn periodic(
  effect: periodic_algebra.PeriodicJobEffect(next),
) -> program_types.DbEffect(next) {
  program_types.JobEffect(algebra.Periodic(effect))
}

pub fn type_policy(
  effect: type_policy_algebra.JobTypePolicyEffect(next),
) -> program_types.DbEffect(next) {
  program_types.JobEffect(algebra.TypePolicy(effect))
}
