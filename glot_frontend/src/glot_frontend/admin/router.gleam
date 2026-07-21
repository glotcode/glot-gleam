import gleam/time/timestamp.{type Timestamp}
import glot_core/route
import glot_frontend/admin/command
import glot_frontend/admin/router_managed as managed
import glot_frontend/admin/router_message as message
import glot_frontend/admin/router_state as state
import glot_frontend/admin/router_view
import lustre/element.{type Element}

pub type Model =
  state.Model

pub type Msg =
  message.Msg

pub fn empty() -> Model {
  managed.empty()
}

pub fn init(
  admin_route: route.AdminRoute,
  is_admin: Bool,
) -> #(Model, command.Command(Msg)) {
  managed.init(admin_route, is_admin)
}

pub fn session_loaded(model: Model) -> #(Model, command.Command(Msg)) {
  managed.session_loaded(model)
}

pub fn update(model: Model, msg: Msg) -> #(Model, command.Command(Msg)) {
  managed.update(model, msg)
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  router_view.view(state.page(model), now)
}
