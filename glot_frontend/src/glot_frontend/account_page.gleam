import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/auth/account_dto
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_frontend/api
import glot_frontend/app_event
import glot_frontend/route
import glot_frontend/top_bar
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem

pub type Model {
  Model(
    account: option.Option(account_dto.AccountResponse),
    username: String,
    status: Status,
  )
}

pub type Status {
  Loading
  Idle
  Saving
  LoggingOut
  SchedulingDelete
  CancelingDelete
  Saved
  Error(String)
}

pub type Msg {
  AccountLoaded(api.ApiResponse(account_dto.AccountResponse))
  UsernameChanged(String)
  UsernameSubmitted
  AccountUpdated(api.ApiResponse(account_dto.AccountResponse))
  LogoutSubmitted
  ScheduleDeleteSubmitted
  DeleteScheduled(api.ApiResponse(Nil))
  CancelDeleteSubmitted
  DeleteCanceled(api.ApiResponse(Nil))
  LoggedOut(api.ApiResponse(Nil))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(account: option.None, username: "", status: Loading),
    api.get_account(AccountLoaded),
  )
}

pub fn update(
  model: Model,
  msg: Msg,
) -> #(Model, Effect(Msg), app_event.AppEvent) {
  case msg {
    AccountLoaded(result) ->
      case result {
        api.ApiSuccess(account) -> {
          #(
            Model(
              account: option.Some(account),
              username: account.username,
              status: Idle,
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }

        api.ApiFailure(error) -> #(
          Model(..model, status: Error(error.message)),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: Error("Could not load account.")),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    UsernameChanged(username) -> #(
      Model(..model, username: username, status: Idle),
      effect.none(),
      app_event.NoAppEvent,
    )

    UsernameSubmitted -> {
      let username = string.trim(model.username)

      case user_model.is_valid_username(username) {
        True -> {
          let request = account_dto.UpdateAccountRequest(username:)
          #(
            Model(..model, username: username, status: Saving),
            api.update_account(request, AccountUpdated),
            app_event.NoAppEvent,
          )
        }

        False -> #(
          Model(
            ..model,
            username: username,
            status: Error(
              "Invalid username: use 3-40 lowercase letters, digits, dots, or hyphens",
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }
    }

    LogoutSubmitted -> #(
      Model(..model, status: LoggingOut),
      api.logout(LoggedOut),
      app_event.NoAppEvent,
    )

    ScheduleDeleteSubmitted -> #(
      Model(..model, status: SchedulingDelete),
      api.schedule_delete_account(DeleteScheduled),
      app_event.NoAppEvent,
    )

    DeleteScheduled(result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, status: Idle),
          api.get_account(AccountLoaded),
          app_event.NoAppEvent,
        )

        api.ApiFailure(error) -> #(
          Model(..model, status: Error(error.message)),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: Error("Could not schedule account deletion.")),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    CancelDeleteSubmitted -> #(
      Model(..model, status: CancelingDelete),
      api.cancel_delete_account(DeleteCanceled),
      app_event.NoAppEvent,
    )

    DeleteCanceled(result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, status: Idle),
          api.get_account(AccountLoaded),
          app_event.NoAppEvent,
        )

        api.ApiFailure(error) -> #(
          Model(..model, status: Error(error.message)),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: Error("Could not cancel account deletion.")),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    AccountUpdated(result) ->
      case result {
        api.ApiSuccess(account) -> {
          #(
            Model(
              account: option.Some(account),
              username: account.username,
              status: Saved,
            ),
            effect.none(),
            app_event.RefreshSession,
          )
        }

        api.ApiFailure(error) -> #(
          Model(..model, status: Error(error.message)),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: Error("Could not update account.")),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    LoggedOut(result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, status: Idle),
          modem.replace(route.to_string(route.Home), option.None, option.None),
          app_event.RefreshSession,
        )

        api.ApiFailure(error) -> #(
          Model(..model, status: Error(error.message)),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: Error("Could not log out.")),
          effect.none(),
          app_event.NoAppEvent,
        )
      }
  }
}

pub fn view(
  model: Model,
  current_user_label: String,
  account_route: route.Route,
) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    top_bar.view(current_user_label, account_route),
    html.main([attribute.class("app-shell app-shell--narrow")], [
      html.section([attribute.class("account-page")], [
        html.h2([attribute.class("account-page__title")], [
          html.text("Account"),
        ]),
        content(model),
      ]),
    ]),
  ])
}

fn content(model: Model) -> Element(Msg) {
  case model.account, model.status {
    option.None, Loading ->
      html.p([attribute.class("account-page__status")], [
        html.text("Loading account..."),
      ])

    option.None, Error(message) ->
      html.div([attribute.class("account-page__empty")], [
        html.p(
          [attribute.class("account-page__status account-page__status--error")],
          [
            html.text(message),
          ],
        ),
        html.a(
          [route.href(route.Login), attribute.class("account-page__link")],
          [
            html.text("Go to login"),
          ],
        ),
      ])

    option.None, _ ->
      html.p([attribute.class("account-page__status")], [
        html.text("No account loaded."),
      ])

    option.Some(account), _ -> account_form(model, account)
  }
}

fn account_form(
  model: Model,
  account: account_dto.AccountResponse,
) -> Element(Msg) {
  html.div([attribute.class("account-page__panels")], [
    html.section([attribute.class("app-panel")], [
      html.h3([attribute.class("account-page__section-title")], [
        html.text("Account Info"),
      ]),
      account_row("Email", email_address_model.to_string(account.email)),
      account_row(
        "Joined",
        timestamp.to_rfc3339(account.joined_at, calendar.utc_offset),
      ),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h3([attribute.class("account-page__section-title")], [
        html.text("Account Settings"),
      ]),
      account_settings_form(model),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h3([attribute.class("account-page__section-title")], [
        html.text("Snippets"),
      ]),
      snippets_section(),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h3([attribute.class("account-page__section-title")], [
        html.text("Danger Zone"),
      ]),
      delete_account_section(account, model.status),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h3([attribute.class("account-page__section-title")], [
        html.text("Session"),
      ]),
      logout_section(model.status),
    ]),
  ])
}

fn account_settings_form(model: Model) -> Element(Msg) {
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
        attribute.value(model.username),
        event.on_input(UsernameChanged),
        attribute.disabled(model.status == Saving),
        attribute.class("account-page__input"),
      ]),
      status_view(model.status),
      html.button(
        [
          attribute.type_("submit"),
          attribute.disabled(is_busy(model.status)),
          attribute.class("account-page__button"),
        ],
        [html.text(button_text(model.status))],
      ),
    ],
  )
}

fn snippets_section() -> Element(Msg) {
  html.div([attribute.class("account-page__empty")], [
    html.p([attribute.class("account-page__status")], [
      html.text("Browse, edit, and delete snippets created with your account."),
    ]),
    html.a(
      [
        route.href(route.AccountSnippets(
          after: option.None,
          before: option.None,
        )),
        attribute.class("account-page__link"),
      ],
      [
        html.text("Manage snippets"),
      ],
    ),
  ])
}

fn account_row(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("account-page__row")], [
    html.span([attribute.class("account-page__row-label")], [html.text(label)]),
    html.span([attribute.class("account-page__row-value")], [html.text(value)]),
  ])
}

fn status_view(status: Status) -> Element(Msg) {
  case status {
    Loading | Idle -> html.text("")
    Saving ->
      html.p([attribute.class("account-page__status")], [
        html.text("Saving account..."),
      ])
    LoggingOut ->
      html.p([attribute.class("account-page__status")], [
        html.text("Logging out..."),
      ])
    SchedulingDelete ->
      html.p([attribute.class("account-page__status")], [
        html.text("Scheduling account deletion..."),
      ])
    CancelingDelete ->
      html.p([attribute.class("account-page__status")], [
        html.text("Canceling account deletion..."),
      ])
    Saved ->
      html.p([attribute.class("account-page__status")], [
        html.text("Account updated."),
      ])
    Error(message) ->
      html.p(
        [attribute.class("account-page__status account-page__status--error")],
        [
          html.text(message),
        ],
      )
  }
}

fn delete_account_section(
  account: account_dto.AccountResponse,
  status: Status,
) -> Element(Msg) {
  let #(description, button_msg, button_class, title, button_label) = case
    account.delete_scheduled
  {
    True -> #(
      delete_account_description(account),
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
    html.p([attribute.class("account-page__label")], [html.text(title)]),
    html.p([attribute.class("account-page__status")], [html.text(description)]),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(is_busy(status)),
        attribute.class(button_class),
        event.on_click(button_msg),
      ],
      [html.text(button_label)],
    ),
  ])
}

fn delete_account_description(account: account_dto.AccountResponse) -> String {
  case account.delete_scheduled_at {
    option.Some(delete_scheduled_at) ->
      "Your account is scheduled for deletion at "
      <> timestamp.to_rfc3339(delete_scheduled_at, calendar.utc_offset)
      <> ". Cancel this if you want to keep your data."
    option.None ->
      "Your account is scheduled for deletion. Cancel this if you want to keep your data."
  }
}

fn logout_section(status: Status) -> Element(Msg) {
  html.div([attribute.class("account-page__logout")], [
    html.p([attribute.class("account-page__status")], [
      html.text("End your current session on this device."),
    ]),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(is_busy(status)),
        attribute.class("account-page__button account-page__button--logout"),
        event.on_click(LogoutSubmitted),
      ],
      [html.text(logout_button_text(status))],
    ),
  ])
}

fn button_text(status: Status) -> String {
  case status {
    Saving -> "Saving..."
    _ -> "Update account"
  }
}

fn logout_button_text(status: Status) -> String {
  case status {
    LoggingOut -> "Logging out..."
    _ -> "Log out"
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

fn is_busy(status: Status) -> Bool {
  case status {
    Saving | LoggingOut | SchedulingDelete | CancelingDelete -> True
    Loading | Idle | Saved | Error(_) -> False
  }
}
