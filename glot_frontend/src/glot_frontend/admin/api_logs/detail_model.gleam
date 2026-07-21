import glot_core/admin/api_log_dto
import glot_core/loadable
import youid/uuid

pub type Model {
  Model(id: uuid.Uuid, log: loadable.Loadable(api_log_dto.ApiLogDetailResponse))
}
