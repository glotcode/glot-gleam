import gleam/time/timestamp.{type Timestamp}
import glot_frontend/admin/command
import glot_frontend/admin/periodic_jobs/list_managed
import glot_frontend/admin/periodic_jobs/list_message
import glot_frontend/admin/periodic_jobs/list_model
import glot_frontend/admin/periodic_jobs/list_view
import lustre/element.{type Element}

pub type Model =
  list_model.Model

pub type Msg =
  list_message.Msg

pub fn init() -> #(Model, command.Command(Msg)) {
  list_managed.init()
}

pub fn ensure_loaded(model: Model) -> #(Model, command.Command(Msg)) {
  list_managed.ensure_loaded(model)
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  list_managed.update(model, msg)
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  list_view.view(model, now)
}
