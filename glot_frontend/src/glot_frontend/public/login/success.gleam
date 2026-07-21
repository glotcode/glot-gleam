import gleam/option
import glot_core/route
import glot_frontend/app/event as app_event
import glot_frontend/public/login/command
import glot_frontend/public/login/model.{type Model, PasskeyIdle, StatusInfo}

pub fn login_succeeded(model: Model) {
  #(
    model.Model(
      ..model,
      status: StatusInfo("You are now logged in."),
      passkey_challenge_id: option.None,
      passkey_status: PasskeyIdle,
    ),
    command.NavigateReplace(route.to_string(route.Public(route.Home))),
    app_event.RefreshSession,
  )
}
