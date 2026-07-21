import glot_core/admin/job_log_dto
import glot_core/loadable
import youid/uuid

pub type Model {
  Model(id: uuid.Uuid, log: loadable.Loadable(job_log_dto.JobLogDetailResponse))
}
