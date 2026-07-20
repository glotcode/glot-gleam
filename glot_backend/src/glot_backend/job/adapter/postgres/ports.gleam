import glot_backend/job/adapter/postgres/job/store as job_store
import glot_backend/job/adapter/postgres/log_store
import glot_backend/job/adapter/postgres/periodic_store
import glot_backend/job/adapter/postgres/type_policy_store
import glot_backend/job/ports
import glot_backend/system/database as db_helpers

pub fn new(db: db_helpers.Db) -> ports.Ports {
  ports.Ports(
    jobs: job_store.new(db),
    periodic: periodic_store.new(db),
    type_policies: type_policy_store.new(db),
    logs: log_store.new(db),
  )
}
