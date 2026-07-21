import glot_core/admin/run_log_dto
import glot_core/loadable
import youid/uuid

pub type Model {
  Model(id: uuid.Uuid, log: loadable.Loadable(run_log_dto.RunLogDetailResponse))
}
