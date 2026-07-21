import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/passkey_dto
import glot_core/auth/platform_model
import glot_core/helpers/timestamp_helpers
import glot_frontend/account/message.{
  type Msg, BeginPasskeySubmitted, DeletePasskeySubmitted,
}

import glot_frontend/account/model.{
  type Model, type PasskeySetupStatus, type PasskeysStatus, type SessionsStatus,
  type Status, CancelingDelete, CreatingPasskey, DeleteError, DeletingPasskey,
  DeletingSession, Idle, IdlePasskeys, IdleSessions, LoadingPasskeys,
  LoadingSessions, LoggingOut, LogoutError, PasskeySaved, PasskeySetupError,
  PasskeySetupIdle, PasskeysError, Saved, Saving, SavingPasskey,
  SchedulingDelete, SessionsError, StartingPasskeySetup, UsernameError,
}
import glot_frontend/ui/delayed_loading
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("account-page__empty")], [
    html.p([attribute.class("account-page__status")], [
      html.text(
        "Add and manage passkeys on your account. The device label is based on the browser and OS used when the passkey was registered.",
      ),
    ]),
    passkeys_status_view(model.passkeys_status),
    passkey_setup_status_view(model.passkey_setup_status),
    passkeys_list(
      model.passkeys,
      model.passkeys_status,
      delayed_loading.is_visible(model.passkeys_loading_indicator),
      now,
    ),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(is_busy(
          model.status,
          model.passkey_setup_status,
          model.sessions_status,
          model.passkeys_status,
        )),
        attribute.class("account-page__button account-page__button--secondary"),
        event.on_click(BeginPasskeySubmitted),
      ],
      [html.text(passkey_button_text(model.passkey_setup_status))],
    ),
  ])
}

fn passkeys_list(
  passkeys: List(passkey_dto.AccountPasskeyResponse),
  passkeys_status: PasskeysStatus,
  show_loading: Bool,
  now: Timestamp,
) -> Element(Msg) {
  case passkeys_status, passkeys, show_loading {
    LoadingPasskeys, [], True -> account_status("Loading passkeys...")

    LoadingPasskeys, [], False -> html.text("")

    _, [], _ ->
      html.p([attribute.class("account-page__status")], [
        html.text("No passkeys added yet."),
      ])

    _, _, _ ->
      html.div(
        [attribute.class("account-page__passkey-list")],
        list.map(passkeys, fn(passkey) {
          passkey_item(passkey, passkeys_status, now)
        }),
      )
  }
}

fn passkey_item(
  account_passkey: passkey_dto.AccountPasskeyResponse,
  passkeys_status: PasskeysStatus,
  now: Timestamp,
) -> Element(Msg) {
  html.div([attribute.class("account-page__passkey-item")], [
    html.div([attribute.class("account-page__passkey-meta")], [
      html.p([attribute.class("account-page__row-value")], [
        html.text(passkey_label(account_passkey)),
      ]),
      html.p([attribute.class("account-page__status")], [
        html.text(
          "Added "
          <> timestamp_helpers.relative_label(account_passkey.created_at, now),
        ),
      ]),
      html.p([attribute.class("account-page__status")], [
        html.text(last_used_label(account_passkey, now)),
      ]),
    ]),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(delete_button_disabled(passkeys_status)),
        attribute.class("account-page__button account-page__button--danger"),
        event.on_click(DeletePasskeySubmitted(account_passkey.id)),
      ],
      [
        html.text(delete_passkey_button_text(
          passkeys_status,
          account_passkey.id,
        )),
      ],
    ),
  ])
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

fn passkeys_status_view(passkeys_status: PasskeysStatus) -> Element(Msg) {
  case passkeys_status {
    PasskeysError(message) ->
      html.p(
        [attribute.class("account-page__status account-page__status--error")],
        [html.text(message)],
      )
    LoadingPasskeys | IdlePasskeys | DeletingPasskey(_) -> html.text("")
  }
}

fn passkey_setup_status_view(
  passkey_setup_status: PasskeySetupStatus,
) -> Element(Msg) {
  case passkey_setup_status {
    PasskeySetupIdle -> html.text("")
    StartingPasskeySetup ->
      html.p([attribute.class("account-page__status")], [
        html.text("Preparing passkey setup..."),
      ])
    CreatingPasskey ->
      html.p([attribute.class("account-page__status")], [
        html.text("Complete the passkey prompt from your browser or device."),
      ])
    SavingPasskey ->
      html.p([attribute.class("account-page__status")], [
        html.text("Saving passkey..."),
      ])
    PasskeySaved ->
      html.p([attribute.class("account-page__status")], [
        html.text("Passkey added."),
      ])
    PasskeySetupError(message) ->
      html.p(
        [attribute.class("account-page__status account-page__status--error")],
        [html.text(message)],
      )
  }
}

fn passkey_button_text(passkey_setup_status: PasskeySetupStatus) -> String {
  case passkey_setup_status {
    StartingPasskeySetup -> "Preparing..."
    CreatingPasskey -> "Waiting for passkey..."
    SavingPasskey -> "Saving..."
    _ -> "Add passkey"
  }
}

fn passkey_label(
  account_passkey: passkey_dto.AccountPasskeyResponse,
) -> String {
  case account_passkey.browser_name, account_passkey.os_name {
    option.Some(browser_name), option.Some(os_name) ->
      platform_model.browser_label(browser_name)
      <> " on "
      <> platform_model.operating_system_label(os_name)
    option.Some(browser_name), option.None ->
      platform_model.browser_label(browser_name)
    option.None, option.Some(os_name) ->
      platform_model.operating_system_label(os_name)
    option.None, option.None -> "Unknown device"
  }
}

fn last_used_label(
  account_passkey: passkey_dto.AccountPasskeyResponse,
  now: Timestamp,
) -> String {
  case account_passkey.last_used_at {
    option.Some(last_used_at) ->
      "Last used " <> timestamp_helpers.relative_label(last_used_at, now)
    option.None -> "Never used for sign-in yet."
  }
}

fn delete_button_disabled(passkeys_status: PasskeysStatus) -> Bool {
  case passkeys_status {
    LoadingPasskeys | DeletingPasskey(_) -> True
    IdlePasskeys | PasskeysError(_) -> False
  }
}

fn delete_passkey_button_text(
  passkeys_status: PasskeysStatus,
  passkey_id: uuid.Uuid,
) -> String {
  case passkeys_status {
    DeletingPasskey(id) if id == passkey_id -> "Deleting..."
    _ -> "Delete"
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
