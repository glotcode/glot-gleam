import glot_frontend/account/message.{
  type Msg, UsernameChanged, UsernameSubmitted,
}

import glot_frontend/account/model.{
  type Model, type PasskeySetupStatus, type PasskeysStatus, type SessionsStatus,
  type Status, CancelingDelete, CreatingPasskey, DeleteError, DeletingPasskey,
  DeletingSession, Idle, IdlePasskeys, IdleSessions, LoadingPasskeys,
  LoadingSessions, LoggingOut, LogoutError, PasskeySaved, PasskeySetupError,
  PasskeySetupIdle, PasskeysError, Saved, Saving, SavingPasskey,
  SchedulingDelete, SessionsError, StartingPasskeySetup, UsernameError,
}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn view(model: Model) -> Element(Msg) {
  html.form(
    [
      attribute.class("account-page__form"),
      event.on_submit(fn(_) { UsernameSubmitted }),
    ],
    [
      html.label(
        [
          attribute.for("account-username"),
          attribute.class("account-page__label"),
        ],
        [
          html.text("Username"),
        ],
      ),
      html.input([
        attribute.id("account-username"),
        attribute.name("username"),
        attribute.type_("text"),
        attribute.autocomplete("username"),
        attribute.value(model.username),
        event.on_input(UsernameChanged),
        attribute.disabled(is_busy(
          model.status,
          model.passkey_setup_status,
          model.sessions_status,
          model.passkeys_status,
        )),
        attribute.class("account-page__input"),
      ]),
      status_view(model.status),
      html.button(
        [
          attribute.type_("submit"),
          attribute.disabled(is_busy(
            model.status,
            model.passkey_setup_status,
            model.sessions_status,
            model.passkeys_status,
          )),
          attribute.class("account-page__button"),
        ],
        [html.text(button_text(model.status))],
      ),
    ],
  )
}

fn status_view(status: Status) -> Element(Msg) {
  case status {
    Idle -> html.text("")
    Saving -> account_status("Saving account...")
    Saved -> account_status("Account updated.")
    UsernameError(message) -> account_error_status(message)
    LoggingOut
    | SchedulingDelete
    | CancelingDelete
    | DeleteError(_)
    | LogoutError(_) -> html.text("")
  }
}

fn account_status(message: String) -> Element(Msg) {
  html.p(
    [
      attribute.class("account-page__status"),
      attribute.attribute("role", "status"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [html.text(message)],
  )
}

fn account_error_status(message: String) -> Element(Msg) {
  html.p(
    [
      attribute.class("account-page__status account-page__status--error"),
      attribute.attribute("role", "alert"),
      attribute.attribute("aria-atomic", "true"),
    ],
    [html.text(message)],
  )
}

fn button_text(status: Status) -> String {
  case status {
    Saving -> "Saving..."
    _ -> "Update account"
  }
}

fn is_busy(
  status: Status,
  passkey_setup_status: PasskeySetupStatus,
  sessions_status: SessionsStatus,
  passkeys_status: PasskeysStatus,
) -> Bool {
  case status {
    Saving | LoggingOut | SchedulingDelete | CancelingDelete -> True
    Idle | Saved | UsernameError(_) | DeleteError(_) | LogoutError(_) ->
      case passkey_setup_status {
        StartingPasskeySetup | CreatingPasskey | SavingPasskey -> True
        PasskeySetupIdle | PasskeySaved | PasskeySetupError(_) ->
          case sessions_status {
            LoadingSessions | DeletingSession(_) -> True
            IdleSessions | SessionsError(_) ->
              case passkeys_status {
                LoadingPasskeys | DeletingPasskey(_) -> True
                IdlePasskeys | PasskeysError(_) -> False
              }
          }
      }
  }
}
