import glot_frontend/app/event as app_event
import glot_frontend/public/login/command
import glot_frontend/public/login/interpreter
import glot_frontend/public/login/managed
import glot_frontend/public/login/message
import glot_frontend/public/login/model
import glot_frontend/public/login/production_ports
import glot_frontend/public/login/view as login_view
import lustre/effect.{type Effect}
import lustre/element.{type Element}

pub type Model =
  model.Model

pub type Msg =
  message.Msg

pub type Step =
  model.Step

pub type Status =
  model.Status

pub type PasskeyStatus =
  model.PasskeyStatus

pub fn init() -> #(Model, Effect(Msg)) {
  let #(model, next_command) = managed.init()
  #(model, interpreter.run(next_command, using: production_ports.new()))
}

pub fn init_managed() -> #(Model, command.Command(Msg)) {
  managed.init()
}

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg), app_event.AppEvent) {
  let #(model, next_command, event) = managed.update(model, msg)
  #(model, interpreter.run(next_command, using: production_ports.new()), event)
}

pub fn update_managed(
  model: Model,
  msg: Msg,
) -> #(Model, command.Command(Msg), app_event.AppEvent) {
  managed.update(model, msg)
}

pub fn view(model: Model) -> Element(Msg) {
  login_view.view(model)
}

pub fn email_submit_msg(step: Step) -> Msg {
  login_view.email_submit_msg(step)
}

pub fn show_send_token_button(step: Step) -> Bool {
  login_view.show_send_token_button(step)
}

pub fn show_passkey_section(supported: Bool) -> Bool {
  login_view.show_passkey_section(supported)
}
