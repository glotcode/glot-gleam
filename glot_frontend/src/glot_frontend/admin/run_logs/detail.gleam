import glot_frontend/admin/command
import glot_frontend/admin/run_logs/detail_managed as managed
import glot_frontend/admin/run_logs/detail_message as message
import glot_frontend/admin/run_logs/detail_model as model
import glot_frontend/admin/run_logs/detail_view as feature_view
import lustre/element.{type Element}
import youid/uuid

pub type Model =
  model.Model

pub type Msg =
  message.Msg

pub fn init(id: uuid.Uuid) -> #(Model, command.Command(Msg)) {
  managed.init(id)
}

pub fn ensure_loaded(model: Model) -> #(Model, command.Command(Msg)) {
  managed.ensure_loaded(model)
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  managed.update(model, msg)
}

pub fn view(model: Model) -> Element(Msg) {
  feature_view.view(model)
}
