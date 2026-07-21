import gleam/time/timestamp.{type Timestamp}
import glot_frontend/admin/command
import glot_frontend/admin/periodic_jobs/managed
import glot_frontend/admin/periodic_jobs/message
import glot_frontend/admin/periodic_jobs/model
import glot_frontend/admin/periodic_jobs/view as periodic_job_view
import lustre/element.{type Element}
import youid/uuid.{type Uuid}

pub type Model =
  model.Model

pub type Msg =
  message.Msg

pub fn init(id: Uuid) -> #(Model, command.Command(Msg)) {
  managed.init(id)
}

pub fn ensure_loaded(model: Model) -> #(Model, command.Command(Msg)) {
  managed.ensure_loaded(model)
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  managed.update(model, msg)
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  periodic_job_view.view(model, now)
}
