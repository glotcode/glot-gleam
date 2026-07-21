import glot_frontend/admin/command
import glot_frontend/admin/config/page_managed
import glot_frontend/admin/config/page_message
import glot_frontend/admin/config/page_model
import glot_frontend/admin/config/page_view
import lustre/element.{type Element}

pub type Model =
  page_model.Model

pub type Msg =
  page_message.Msg

pub fn init() -> #(Model, command.Command(Msg)) {
  page_managed.init()
}

pub fn ensure_loaded(model: Model) -> #(Model, command.Command(Msg)) {
  page_managed.ensure_loaded(model)
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  page_managed.update(model, msg)
}

pub fn view(model: Model) -> Element(Msg) {
  page_view.view(model)
}
