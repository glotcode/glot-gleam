import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/loadable
import glot_frontend/account/command
import glot_frontend/account/interpreter
import glot_frontend/account/message.{type Msg, RuntimeLoaded}
import glot_frontend/account/model.{
  type Model, Idle, IdlePasskeys, LoadingSessions, Model, PasskeySetupIdle,
}
import glot_frontend/account/production_ports
import glot_frontend/account/update as account_update
import glot_frontend/account/view as account_view
import glot_frontend/app/event as app_event
import glot_frontend/ui/delayed_loading
import lustre/effect.{type Effect}
import lustre/element.{type Element}

pub fn init() -> #(Model, Effect(Msg)) {
  let #(model, command) = init_managed()
  #(model, interpret(command))
}

pub fn init_managed() -> #(Model, command.Command(Msg)) {
  #(
    Model(
      account: loadable.Loading,
      username: "",
      status: Idle,
      account_loading_indicator: delayed_loading.idle(),
      danger_zone_expanded: False,
      passkey_supported: False,
      current_session_id: option.None,
      sessions: [],
      sessions_status: LoadingSessions,
      sessions_loading_indicator: delayed_loading.idle(),
      passkey_setup_status: PasskeySetupIdle,
      passkeys: [],
      passkeys_status: IdlePasskeys,
      passkeys_loading_indicator: delayed_loading.idle(),
    ),
    command.DetectPasskeySupport(RuntimeLoaded),
  )
}

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg), app_event.AppEvent) {
  let #(model, command, event) = account_update.update(model, msg)
  #(model, interpret(command), event)
}

pub fn update_managed(
  model: Model,
  msg: Msg,
) -> #(Model, command.Command(Msg), app_event.AppEvent) {
  account_update.update(model, msg)
}

fn interpret(command: command.Command(Msg)) -> Effect(Msg) {
  interpreter.run(command, using: production_ports.new())
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  account_view.view(model, now)
}

pub fn should_show_passkey_section(passkey_supported: Bool) -> Bool {
  passkey_supported
}
