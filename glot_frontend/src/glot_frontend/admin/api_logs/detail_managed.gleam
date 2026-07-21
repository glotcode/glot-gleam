import glot_core/admin/api_log_dto
import glot_core/loadable
import glot_frontend/admin/api_logs/detail_message.{LogLoaded}
import glot_frontend/admin/api_logs/detail_model.{Model}
import glot_frontend/admin/command as admin_effect
import glot_frontend/admin/ui/loadable as loadable_effect
import glot_frontend/api/response as api_response
import youid/uuid

pub type Model =
  detail_model.Model

pub type Msg =
  detail_message.Msg

pub fn init(id: uuid.Uuid) -> #(Model, admin_effect.Command(Msg)) {
  #(Model(id: id, log: loadable.NotLoaded), admin_effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, admin_effect.Command(Msg)) {
  case
    loadable_effect.ensure_loaded(
      model.log,
      admin_effect.get_admin_api_log(
        api_log_dto.GetApiLogRequest(id: model.id),
        LogLoaded,
      ),
    )
  {
    #(next_log, next_effect) -> #(Model(..model, log: next_log), next_effect)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, admin_effect.Command(Msg)) {
  case msg {
    LogLoaded(result) ->
      case result {
        api_response.Success(response) -> #(
          Model(..model, log: loadable.Loaded(response.log)),
          admin_effect.none(),
        )
        api_response.ApiFailure(error) -> #(
          Model(
            ..model,
            log: loadable.LoadError(api_response.error_message(error)),
          ),
          admin_effect.none(),
        )
        api_response.HttpFailure(_) -> #(
          Model(..model, log: loadable.LoadError("Could not load API log.")),
          admin_effect.none(),
        )
      }
  }
}
