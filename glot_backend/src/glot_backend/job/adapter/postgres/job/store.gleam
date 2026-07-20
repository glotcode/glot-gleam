import glot_backend/job/adapter/postgres/job/read
import glot_backend/job/adapter/postgres/job/write
import glot_backend/job/ports/job_store
import glot_backend/system/database as db_helpers

pub fn new(db: db_helpers.Db) -> job_store.JobStore {
  job_store.JobStore(
    list_jobs: fn(filter, pagination) { read.list(db, filter, pagination) },
    summarize_jobs: fn(filter, now) { read.summarize(db, filter, now) },
    get_next_job: fn(now, pending_status) {
      read.get_next(db, now, pending_status)
    },
    get_expired_running_job: fn(now, running_status) {
      read.get_expired_running(db, now, running_status)
    },
    get_job_by_id: fn(id) { read.get_by_id(db, id) },
    create_job: fn(job) { write.create(db, job) },
    update_job: fn(job) { write.update(db, job) },
    delete_job: fn(id) { write.delete(db, id) },
    delete_before: fn(before, statuses) {
      write.delete_before(db, before, statuses)
    },
  )
}
