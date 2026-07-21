import gleam/time/timestamp.{type Timestamp}
import glot_frontend/admin/command
import glot_frontend/admin/jobs/list_managed as managed
import glot_frontend/admin/jobs/list_message as message
import glot_frontend/admin/jobs/list_model as model
import glot_frontend/admin/jobs/list_view
import lustre/element.{type Element}

pub type Model =
  model.Model

pub type Msg =
  message.Msg

pub fn init() -> #(Model, command.Command(Msg)) {
  managed.init()
}

pub fn ensure_loaded(model: Model) -> #(Model, command.Command(Msg)) {
  managed.ensure_loaded(model)
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  managed.update(model, msg)
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  list_view.view(model, now)
}
