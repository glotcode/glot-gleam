import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/account_dto
import glot_core/helpers/timestamp_helpers
import glot_frontend/account/message.{
  type Msg, CancelDeleteSubmitted, ScheduleDeleteSubmitted, ToggleDangerZone,
}

import glot_frontend/account/model.{
  type PasskeySetupStatus, type PasskeysStatus, type SessionsStatus, type Status,
  CancelingDelete, CreatingPasskey, DeleteError, DeletingPasskey,
  DeletingSession, Idle, IdlePasskeys, IdleSessions, LoadingPasskeys,
  LoadingSessions, LoggingOut, LogoutError, PasskeySaved, PasskeySetupError,
  PasskeySetupIdle, PasskeysError, Saved, Saving, SavingPasskey,
  SchedulingDelete, SessionsError, StartingPasskeySetup, UsernameError,
}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn view(
  account: account_dto.AccountResponse,
  status: Status,
  is_expanded: Bool,
  now: Timestamp,
) -> Element(Msg) {
  let #(description, button_msg, button_class, title, button_label) = case
    account.delete_scheduled
  {
    True -> #(
      delete_account_description(account, now),
      CancelDeleteSubmitted,
      "account-page__button account-page__button--secondary",
      "Delete scheduled",
      delete_button_text(status, account.delete_scheduled),
    )
    False -> #(
      "Delete your account and all associated data. This action schedules permanent deletion of everything stored for this account.",
      ScheduleDeleteSubmitted,
      "account-page__button account-page__button--danger",
      "Delete account",
      delete_button_text(status, account.delete_scheduled),
    )
  }

  html.div([attribute.class("account-page__danger-zone")], [
    html.button(
      [
        attribute.type_("button"),
        attribute.class("account-page__button account-page__button--secondary"),
        event.on_click(ToggleDangerZone),
      ],
      [html.text(danger_zone_toggle_text(is_expanded))],
    ),
    case is_expanded {
      True ->
        html.div([attribute.class("account-page__danger-zone-body")], [
          html.p([attribute.class("account-page__label")], [html.text(title)]),
          html.p([attribute.class("account-page__status")], [
            html.text(description),
          ]),
          delete_status_view(status),
          html.button(
            [
              attribute.type_("button"),
              attribute.disabled(is_busy(
                status,
                PasskeySetupIdle,
                IdleSessions,
                IdlePasskeys,
              )),
              attribute.class(button_class),
              event.on_click(button_msg),
            ],
            [html.text(button_label)],
          ),
        ])
      False -> html.text("")
    },
  ])
}

fn danger_zone_toggle_text(is_expanded: Bool) -> String {
  case is_expanded {
    True -> "Hide danger zone"
    False -> "Show danger zone"
  }
}

fn delete_status_view(status: Status) -> Element(Msg) {
  case status {
    SchedulingDelete ->
      html.p([attribute.class("account-page__status")], [
        html.text("Scheduling account deletion..."),
      ])
    CancelingDelete ->
      html.p([attribute.class("account-page__status")], [
        html.text("Canceling account deletion..."),
      ])
    DeleteError(message) ->
      html.p(
        [attribute.class("account-page__status account-page__status--error")],
        [
          html.text(message),
        ],
      )
    Idle | Saving | LoggingOut | Saved | UsernameError(_) | LogoutError(_) ->
      html.text("")
  }
}

fn delete_account_description(
  account: account_dto.AccountResponse,
  now: Timestamp,
) -> String {
  case account.delete_scheduled_at {
    option.Some(delete_scheduled_at) ->
      "Your account is scheduled for deletion "
      <> timestamp_helpers.relative_label(delete_scheduled_at, now)
      <> ". Cancel this if you want to keep your data."
    option.None ->
      "Your account is scheduled for deletion. Cancel this if you want to keep your data."
  }
}

fn delete_button_text(status: Status, delete_scheduled: Bool) -> String {
  case status {
    SchedulingDelete -> "Scheduling..."
    CancelingDelete -> "Canceling..."
    _ ->
      case delete_scheduled {
        True -> "Cancel deletion"
        False -> "Delete account"
      }
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
