import glot_frontend/admin/command
import glot_frontend/admin/jobs/policies_managed
import glot_frontend/admin/jobs/policies_message
import glot_frontend/admin/jobs/policies_model
import glot_frontend/admin/jobs/policies_view
import lustre/element.{type Element}

pub type Model =
  policies_model.Model

pub type Msg =
  policies_message.Msg

pub fn init() -> #(Model, command.Command(Msg)) {
  policies_managed.init()
}

pub fn ensure_loaded(model: Model) -> #(Model, command.Command(Msg)) {
  policies_managed.ensure_loaded(model)
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  policies_managed.update(model, msg)
}

pub fn view(model: Model) -> Element(Msg) {
  policies_view.view(model)
}
