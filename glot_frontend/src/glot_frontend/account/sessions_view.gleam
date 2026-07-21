import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/account_session_dto
import glot_core/auth/platform_model
import glot_core/helpers/timestamp_helpers
import glot_frontend/account/message.{
  type Msg, DeleteSessionSubmitted, LogoutSubmitted,
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
        "Review active account sessions and revoke any you no longer trust.",
      ),
    ]),
    sessions_status_view(model.sessions_status),
    sessions_list(
      model.sessions,
      model.current_session_id,
      model.sessions_status,
      delayed_loading.is_visible(model.sessions_loading_indicator),
      now,
    ),
    logout_section(model.status, model.sessions_status),
  ])
}

fn sessions_list(
  sessions: List(account_session_dto.AccountSessionResponse),
  current_session_id: option.Option(uuid.Uuid),
  sessions_status: SessionsStatus,
  show_loading: Bool,
  now: Timestamp,
) -> Element(Msg) {
  case sessions_status, sessions, show_loading {
    LoadingSessions, [], True -> account_status("Loading sessions...")

    LoadingSessions, [], False -> html.text("")

    _, [], _ ->
      html.p([attribute.class("account-page__status")], [
        html.text("No active sessions found."),
      ])

    _, _, _ ->
      html.div(
        [attribute.class("account-page__passkey-list")],
        list.map(sessions, fn(account_session) {
          session_item(
            account_session,
            current_session_id,
            sessions_status,
            now,
          )
        }),
      )
  }
}

fn session_item(
  account_session: account_session_dto.AccountSessionResponse,
  current_session_id: option.Option(uuid.Uuid),
  sessions_status: SessionsStatus,
  now: Timestamp,
) -> Element(Msg) {
  html.div([attribute.class("account-page__passkey-item")], [
    html.div([attribute.class("account-page__passkey-meta")], [
      html.p([attribute.class("account-page__row-value")], [
        html.text(session_label(account_session)),
      ]),
      html.p([attribute.class("account-page__status")], [
        html.text(ip_label(account_session.ip)),
      ]),
      html.p([attribute.class("account-page__status")], [
        html.text(current_session_label(account_session, current_session_id)),
      ]),
      html.p([attribute.class("account-page__status")], [
        html.text(last_activity_label(account_session, now)),
      ]),
      html.p([attribute.class("account-page__status")], [
        html.text(
          "Started "
          <> timestamp_helpers.relative_label(account_session.created_at, now),
        ),
      ]),
    ]),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(delete_session_button_disabled(sessions_status)),
        attribute.class("account-page__button account-page__button--danger"),
        event.on_click(DeleteSessionSubmitted(account_session.id)),
      ],
      [
        html.text(delete_session_button_text(
          sessions_status,
          account_session.id,
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

fn sessions_status_view(sessions_status: SessionsStatus) -> Element(Msg) {
  case sessions_status {
    SessionsError(message) ->
      html.p(
        [attribute.class("account-page__status account-page__status--error")],
        [html.text(message)],
      )
    LoadingSessions | IdleSessions | DeletingSession(_) -> html.text("")
  }
}

fn logout_section(
  status: Status,
  sessions_status: SessionsStatus,
) -> Element(Msg) {
  html.div([attribute.class("account-page__logout")], [
    html.p([attribute.class("account-page__status")], [
      html.text("End your current session on this device."),
    ]),
    logout_status_view(status),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(is_busy(
          status,
          PasskeySetupIdle,
          sessions_status,
          IdlePasskeys,
        )),
        attribute.class("account-page__button account-page__button--logout"),
        event.on_click(LogoutSubmitted),
      ],
      [html.text(logout_button_text(status))],
    ),
  ])
}

fn logout_status_view(status: Status) -> Element(Msg) {
  case status {
    LoggingOut ->
      html.p([attribute.class("account-page__status")], [
        html.text("Logging out..."),
      ])
    LogoutError(message) ->
      html.p(
        [attribute.class("account-page__status account-page__status--error")],
        [
          html.text(message),
        ],
      )
    Idle
    | Saving
    | SchedulingDelete
    | CancelingDelete
    | Saved
    | UsernameError(_)
    | DeleteError(_) -> html.text("")
  }
}

fn logout_button_text(status: Status) -> String {
  case status {
    LoggingOut -> "Logging out..."
    _ -> "Log out"
  }
}

fn session_label(
  account_session: account_session_dto.AccountSessionResponse,
) -> String {
  case account_session.browser_name, account_session.os_name {
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

fn ip_label(ip: option.Option(String)) -> String {
  case ip {
    option.Some(value) -> "IP " <> value
    option.None -> "IP unavailable"
  }
}

fn current_session_label(
  account_session: account_session_dto.AccountSessionResponse,
  current_session_id: option.Option(uuid.Uuid),
) -> String {
  case current_session_id {
    option.Some(id) if id == account_session.id -> "Current session"
    _ -> "Active session"
  }
}

fn last_activity_label(
  account_session: account_session_dto.AccountSessionResponse,
  now: Timestamp,
) -> String {
  "Last active "
  <> timestamp_helpers.relative_label(account_session.last_activity_at, now)
}

fn delete_session_button_disabled(sessions_status: SessionsStatus) -> Bool {
  case sessions_status {
    LoadingSessions | DeletingSession(_) -> True
    IdleSessions | SessionsError(_) -> False
  }
}

fn delete_session_button_text(
  sessions_status: SessionsStatus,
  session_id: uuid.Uuid,
) -> String {
  case sessions_status {
    DeletingSession(id) if id == session_id -> "Deleting..."
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
