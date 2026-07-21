import glot_frontend/admin/command
import glot_frontend/admin/rate_limits/managed
import glot_frontend/admin/rate_limits/message
import glot_frontend/admin/rate_limits/model
import glot_frontend/admin/rate_limits/view as rate_limits_view
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

pub fn view(model: Model) -> Element(Msg) {
  rate_limits_view.view(model)
}
