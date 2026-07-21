import glot_core/admin/periodic_job_dto
import glot_core/loadable

pub type Model {
  Model(
    periodic_jobs: loadable.Loadable(List(periodic_job_dto.PeriodicJobResponse)),
  )
}
