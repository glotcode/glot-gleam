import glot_backend/job/ports/job_store.{type JobStore}
import glot_backend/job/ports/log_store.{type LogStore}
import glot_backend/job/ports/periodic_store.{type PeriodicStore}
import glot_backend/job/ports/type_policy_store.{type TypePolicyStore}

pub type Ports {
  Ports(
    jobs: JobStore,
    periodic: PeriodicStore,
    type_policies: TypePolicyStore,
    logs: LogStore,
  )
}
