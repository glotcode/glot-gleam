import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/account_dto
import glot_core/auth/platform_model
import glot_core/auth/passkey_dto
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/timestamp_helpers
import glot_core/route
import glot_core/validation_error
import glot_frontend/api
import glot_frontend/app_event
import glot_frontend/passkey
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import youid/uuid

pub type Model {
  Model(
    account: option.Option(account_dto.AccountResponse),
    username: String,
    status: Status,
    passkey_supported: Bool,
    passkey_setup_status: PasskeySetupStatus,
    passkeys: List(passkey_dto.AccountPasskeyResponse),
    passkeys_status: PasskeysStatus,
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
  LoadError(String)
  UsernameError(String)
  DeleteError(String)
  LogoutError(String)
}

pub type PasskeySetupStatus {
  PasskeySetupIdle
  StartingPasskeySetup
  CreatingPasskey
  SavingPasskey
  PasskeySaved
  PasskeySetupError(String)
}

pub type PasskeysStatus {
  LoadingPasskeys
  IdlePasskeys
  DeletingPasskey(uuid.Uuid)
  PasskeysError(String)
}

pub type Msg {
  AccountLoaded(api.ApiResponse(account_dto.AccountResponse))
  AccountPasskeysLoaded(api.ApiResponse(passkey_dto.ListAccountPasskeysResponse))
  UsernameChanged(String)
  UsernameSubmitted
  AccountUpdated(api.ApiResponse(account_dto.AccountResponse))
  BeginPasskeySubmitted
  BeganPasskeyRegistration(
    api.ApiResponse(passkey_dto.BeginPasskeyRegistrationResponse),
  )
  PasskeyRegistrationCreated(
    uuid.Uuid,
    Result(passkey.RegistrationResult, passkey.PasskeyError),
  )
  FinishedPasskeyRegistration(api.ApiResponse(Nil))
  DeletePasskeySubmitted(uuid.Uuid)
  DeletedPasskey(uuid.Uuid, api.ApiResponse(Nil))
  LogoutSubmitted
  ScheduleDeleteSubmitted
  DeleteScheduled(api.ApiResponse(Nil))
  CancelDeleteSubmitted
  DeleteCanceled(api.ApiResponse(Nil))
  LoggedOut(api.ApiResponse(Nil))
}

pub fn init() -> #(Model, Effect(Msg)) {
  let passkey_supported = passkey.is_supported()
  let effects = case should_show_passkey_section(passkey_supported) {
    True -> [
      api.get_account(AccountLoaded),
      api.get_account_passkeys(AccountPasskeysLoaded),
    ]
    False -> [api.get_account(AccountLoaded)]
  }

  #(
    Model(
      account: option.None,
      username: "",
      status: Loading,
      passkey_supported: passkey_supported,
      passkey_setup_status: PasskeySetupIdle,
      passkeys: [],
      passkeys_status: case passkey_supported {
        True -> LoadingPasskeys
        False -> IdlePasskeys
      },
    ),
    effect.batch(effects),
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
              ..model,
              account: option.Some(account),
              username: account.username,
              status: Idle,
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }

        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(api.error_message(error))),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load account.")),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    AccountPasskeysLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            passkeys: response.passkeys,
            passkeys_status: IdlePasskeys,
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError(api.error_message(error)),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError("Could not load passkeys."),
          ),
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

      let validation =
        user_model.validate_username(username)
        |> result.map_error(validation_error.message)

      case validation {
        Ok(_) -> {
          let request = account_dto.UpdateAccountRequest(username:)
          #(
            Model(..model, username: username, status: Saving),
            api.update_account(request, AccountUpdated),
            app_event.NoAppEvent,
          )
        }

        _ -> #(
          Model(
            ..model,
            username: username,
            status: UsernameError(result.unwrap_error(
              validation,
              "Invalid username.",
            )),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }
    }

    AccountUpdated(result) ->
      case result {
        api.ApiSuccess(account) -> {
          #(
            Model(
              ..model,
              account: option.Some(account),
              username: account.username,
              status: Saved,
            ),
            effect.none(),
            app_event.RefreshSession,
          )
        }

        api.ApiFailure(error) -> #(
          Model(..model, status: UsernameError(api.error_message(error))),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: UsernameError("Could not update account.")),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    BeginPasskeySubmitted -> #(
      Model(..model, passkey_setup_status: StartingPasskeySetup),
      api.begin_passkey_registration(BeganPasskeyRegistration),
      app_event.NoAppEvent,
    )

    BeganPasskeyRegistration(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, passkey_setup_status: CreatingPasskey),
          passkey.begin_registration(response, fn(registration_result) {
            PasskeyRegistrationCreated(
              response.challenge_id,
              registration_result,
            )
          }),
          app_event.NoAppEvent,
        )

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(api.error_message(error)),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(
              "Could not start passkey setup.",
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    PasskeyRegistrationCreated(challenge_id, registration_result) ->
      case registration_result {
        Ok(registration) -> {
          let request =
            passkey_dto.FinishPasskeyRegistrationRequest(
              challenge_id: challenge_id,
              attestation_object: registration.attestation_object,
              client_data_json: registration.client_data_json,
            )
          #(
            Model(..model, passkey_setup_status: SavingPasskey),
            api.finish_passkey_registration(request, FinishedPasskeyRegistration),
            app_event.NoAppEvent,
          )
        }

        Error(error) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(passkey.error_message(error)),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    FinishedPasskeyRegistration(result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySaved,
            passkeys_status: LoadingPasskeys,
          ),
          api.get_account_passkeys(AccountPasskeysLoaded),
          app_event.NoAppEvent,
        )

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(api.error_message(error)),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            passkey_setup_status: PasskeySetupError(
              "Could not save the new passkey.",
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    DeletePasskeySubmitted(id) -> {
      let request = passkey_dto.DeleteAccountPasskeyRequest(id:)
      #(
        Model(..model, passkeys_status: DeletingPasskey(id)),
        api.delete_account_passkey(request, fn(result) { DeletedPasskey(id, result) }),
        app_event.NoAppEvent,
      )
    }

    DeletedPasskey(_id, result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, passkeys_status: LoadingPasskeys),
          api.get_account_passkeys(AccountPasskeysLoaded),
          app_event.NoAppEvent,
        )

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError(api.error_message(error)),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError("Could not delete passkey."),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
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
          Model(..model, status: DeleteError(api.error_message(error))),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            status: DeleteError("Could not schedule account deletion."),
          ),
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
          Model(..model, status: DeleteError(api.error_message(error))),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            status: DeleteError("Could not cancel account deletion."),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    LoggedOut(result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, status: Idle),
          modem.replace(
            route.to_string(route.Public(route.Home)),
            option.None,
            option.None,
          ),
          app_event.RefreshSession,
        )

        api.ApiFailure(error) -> #(
          Model(..model, status: LogoutError(api.error_message(error))),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: LogoutError("Could not log out.")),
          effect.none(),
          app_event.NoAppEvent,
        )
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell app-shell--narrow")], [
      html.section([attribute.class("account-page")], [
        html.h2([attribute.class("account-page__title")], [
          html.text("Account"),
        ]),
        content(model, now),
      ]),
    ]),
  ])
}

fn content(model: Model, now: Timestamp) -> Element(Msg) {
  case model.account, model.status {
    option.None, Loading ->
      html.p([attribute.class("account-page__status")], [
        html.text("Loading account..."),
      ])

    option.None, LoadError(message) ->
      html.div([attribute.class("account-page__empty")], [
        html.p(
          [attribute.class("account-page__status account-page__status--error")],
          [
            html.text(message),
          ],
        ),
        html.a(
          [
            route.href(route.Public(route.Login)),
            attribute.class("account-page__link"),
          ],
          [
            html.text("Go to login"),
          ],
        ),
      ])

    option.None, _ ->
      html.p([attribute.class("account-page__status")], [
        html.text("No account loaded."),
      ])

    option.Some(account), _ -> account_form(model, account, now)
  }
}

fn account_form(
  model: Model,
  account: account_dto.AccountResponse,
  now: Timestamp,
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
    case should_show_passkey_section(model.passkey_supported) {
      True ->
        html.section([attribute.class("app-panel")], [
          html.h3([attribute.class("account-page__section-title")], [
            html.text("Passkeys"),
          ]),
          passkey_section(model, now),
        ])
      False -> html.text("")
    },
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
      delete_account_section(account, model.status, now),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h3([attribute.class("account-page__section-title")], [
        html.text("Session"),
      ]),
      logout_section(model.status),
    ]),
  ])
}

pub fn should_show_passkey_section(passkey_supported: Bool) -> Bool {
  passkey_supported
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
        attribute.disabled(
          is_busy(model.status, model.passkey_setup_status, model.passkeys_status),
        ),
        attribute.class("account-page__input"),
      ]),
      status_view(model.status),
      html.button(
        [
          attribute.type_("submit"),
          attribute.disabled(
            is_busy(model.status, model.passkey_setup_status, model.passkeys_status),
          ),
          attribute.class("account-page__button"),
        ],
        [html.text(button_text(model.status))],
      ),
    ],
  )
}

fn passkey_section(model: Model, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("account-page__empty")], [
    html.p([attribute.class("account-page__status")], [
      html.text(
        "Add and manage passkeys on your account. The device label is based on the browser and OS used when the passkey was registered.",
      ),
    ]),
    passkeys_status_view(model.passkeys_status),
    passkey_setup_status_view(model.passkey_setup_status),
    passkeys_list(model.passkeys, model.passkeys_status, now),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(
          is_busy(model.status, model.passkey_setup_status, model.passkeys_status),
        ),
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
  now: Timestamp,
) -> Element(Msg) {
  case passkeys_status, passkeys {
    LoadingPasskeys, [] ->
      html.p([attribute.class("account-page__status")], [
        html.text("Loading passkeys..."),
      ])

    _, [] ->
      html.p([attribute.class("account-page__status")], [
        html.text("No passkeys added yet."),
      ])

    _, _ ->
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
          "Added " <> timestamp_helpers.relative_label(account_passkey.created_at, now),
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
      [html.text(delete_passkey_button_text(passkeys_status, account_passkey.id))],
    ),
  ])
}

fn snippets_section() -> Element(Msg) {
  html.div([attribute.class("account-page__empty")], [
    html.p([attribute.class("account-page__status")], [
      html.text("Browse, edit, and delete snippets created with your account."),
    ]),
    html.a(
      [
        route.href(
          route.Account(route.AccountSnippets(
            after: option.None,
            before: option.None,
          )),
        ),
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
    Saved ->
      html.p([attribute.class("account-page__status")], [
        html.text("Account updated."),
      ])
    UsernameError(message) ->
      html.p(
        [attribute.class("account-page__status account-page__status--error")],
        [
          html.text(message),
        ],
      )
    LoggingOut
    | SchedulingDelete
    | CancelingDelete
    | LoadError(_)
    | DeleteError(_)
    | LogoutError(_) -> html.text("")
  }
}

fn delete_account_section(
  account: account_dto.AccountResponse,
  status: Status,
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
    html.p([attribute.class("account-page__label")], [html.text(title)]),
    html.p([attribute.class("account-page__status")], [html.text(description)]),
    delete_status_view(status),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(is_busy(status, PasskeySetupIdle, IdlePasskeys)),
        attribute.class(button_class),
        event.on_click(button_msg),
      ],
      [html.text(button_label)],
    ),
  ])
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
    Loading
    | Idle
    | Saving
    | LoggingOut
    | Saved
    | LoadError(_)
    | UsernameError(_)
    | LogoutError(_) -> html.text("")
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

fn logout_section(status: Status) -> Element(Msg) {
  html.div([attribute.class("account-page__logout")], [
    html.p([attribute.class("account-page__status")], [
      html.text("End your current session on this device."),
    ]),
    logout_status_view(status),
    html.button(
      [
        attribute.type_("button"),
        attribute.disabled(is_busy(status, PasskeySetupIdle, IdlePasskeys)),
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
    Loading
    | Idle
    | Saving
    | SchedulingDelete
    | CancelingDelete
    | Saved
    | LoadError(_)
    | UsernameError(_)
    | DeleteError(_) -> html.text("")
  }
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

fn passkey_button_text(passkey_setup_status: PasskeySetupStatus) -> String {
  case passkey_setup_status {
    StartingPasskeySetup -> "Preparing..."
    CreatingPasskey -> "Waiting for passkey..."
    SavingPasskey -> "Saving..."
    _ -> "Add passkey"
  }
}

fn passkey_label(account_passkey: passkey_dto.AccountPasskeyResponse) -> String {
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
  passkeys_status: PasskeysStatus,
) -> Bool {
  case status {
    Saving | LoggingOut | SchedulingDelete | CancelingDelete -> True
    Loading
    | Idle
    | Saved
    | LoadError(_)
    | UsernameError(_)
    | DeleteError(_)
    | LogoutError(_) ->
      case passkey_setup_status {
        StartingPasskeySetup | CreatingPasskey | SavingPasskey -> True
        PasskeySetupIdle | PasskeySaved | PasskeySetupError(_) ->
          case passkeys_status {
            LoadingPasskeys | DeletingPasskey(_) -> True
            IdlePasskeys | PasskeysError(_) -> False
          }
      }
  }
}
