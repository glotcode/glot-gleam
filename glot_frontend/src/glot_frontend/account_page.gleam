import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_core/auth/account_dto
import glot_core/auth/account_session_dto
import glot_core/auth/passkey_dto
import glot_core/auth/platform_model
import glot_core/auth/session_dto
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/timestamp_helpers
import glot_core/loadable
import glot_core/route
import glot_core/validation_error
import glot_frontend/api
import glot_frontend/app_event
import glot_frontend/delayed_loading
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
    account: loadable.Loadable(account_dto.AccountResponse),
    username: String,
    status: Status,
    account_loading_indicator: delayed_loading.State,
    danger_zone_expanded: Bool,
    passkey_supported: Bool,
    current_session_id: option.Option(uuid.Uuid),
    sessions: List(account_session_dto.AccountSessionResponse),
    sessions_status: SessionsStatus,
    sessions_loading_indicator: delayed_loading.State,
    passkey_setup_status: PasskeySetupStatus,
    passkeys: List(passkey_dto.AccountPasskeyResponse),
    passkeys_status: PasskeysStatus,
    passkeys_loading_indicator: delayed_loading.State,
  )
}

pub type Status {
  Idle
  Saving
  LoggingOut
  SchedulingDelete
  CancelingDelete
  Saved
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

pub type SessionsStatus {
  LoadingSessions
  IdleSessions
  DeletingSession(uuid.Uuid)
  SessionsError(String)
}

pub type PasskeysStatus {
  LoadingPasskeys
  IdlePasskeys
  DeletingPasskey(uuid.Uuid)
  PasskeysError(String)
}

pub type Msg {
  AccountLoaded(api.ApiResponse(account_dto.AccountResponse))
  AccountLoadingDelayElapsed(Int)
  SessionLoaded(api.ApiResponse(option.Option(session_dto.SessionResponse)))
  AccountSessionsLoaded(
    api.ApiResponse(account_session_dto.ListAccountSessionsResponse),
  )
  SessionsLoadingDelayElapsed(Int)
  AccountPasskeysLoaded(
    api.ApiResponse(passkey_dto.ListAccountPasskeysResponse),
  )
  PasskeysLoadingDelayElapsed(Int)
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
  DeleteSessionSubmitted(uuid.Uuid)
  DeletedSession(uuid.Uuid, api.ApiResponse(Nil))
  DeletePasskeySubmitted(uuid.Uuid)
  DeletedPasskey(uuid.Uuid, api.ApiResponse(Nil))
  LogoutSubmitted
  ScheduleDeleteSubmitted
  DeleteScheduled(api.ApiResponse(Nil))
  CancelDeleteSubmitted
  DeleteCanceled(api.ApiResponse(Nil))
  ToggleDangerZone
  LoggedOut(api.ApiResponse(Nil))
}

pub fn init() -> #(Model, Effect(Msg)) {
  let passkey_supported = passkey.is_supported()
  let #(account_loading_indicator, account_delay_effect) =
    delayed_loading.start(delayed_loading.idle(), AccountLoadingDelayElapsed)
  let #(sessions_loading_indicator, sessions_delay_effect) =
    delayed_loading.start(delayed_loading.idle(), SessionsLoadingDelayElapsed)
  let #(passkeys_loading_indicator, passkeys_delay_effects) = case
    should_show_passkey_section(passkey_supported)
  {
    True -> {
      let #(indicator, delay_effect) =
        delayed_loading.start(
          delayed_loading.idle(),
          PasskeysLoadingDelayElapsed,
        )
      #(indicator, [delay_effect])
    }
    False -> #(delayed_loading.idle(), [])
  }
  let passkey_effects = case should_show_passkey_section(passkey_supported) {
    True -> [
      api.list_account_passkeys(AccountPasskeysLoaded),
      ..passkeys_delay_effects
    ]
    False -> []
  }
  let effects = [
    api.get_account(AccountLoaded),
    api.get_session(SessionLoaded),
    api.list_account_sessions(AccountSessionsLoaded),
    account_delay_effect,
    sessions_delay_effect,
    ..passkey_effects
  ]

  #(
    Model(
      account: loadable.Loading,
      username: "",
      status: Idle,
      account_loading_indicator:,
      danger_zone_expanded: False,
      passkey_supported: passkey_supported,
      current_session_id: option.None,
      sessions: [],
      sessions_status: LoadingSessions,
      sessions_loading_indicator:,
      passkey_setup_status: PasskeySetupIdle,
      passkeys: [],
      passkeys_status: case passkey_supported {
        True -> LoadingPasskeys
        False -> IdlePasskeys
      },
      passkeys_loading_indicator:,
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
              account: loadable.Loaded(account),
              username: account.username,
              status: Idle,
              account_loading_indicator: delayed_loading.finish(
                model.account_loading_indicator,
              ),
            ),
            effect.none(),
            app_event.NoAppEvent,
          )
        }

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            account: loadable.LoadError(api.error_message(error)),
            account_loading_indicator: delayed_loading.finish(
              model.account_loading_indicator,
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            account: loadable.LoadError("Could not load account."),
            account_loading_indicator: delayed_loading.finish(
              model.account_loading_indicator,
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    AccountLoadingDelayElapsed(generation) -> #(
      Model(
        ..model,
        account_loading_indicator: delayed_loading.reveal(
          model.account_loading_indicator,
          generation,
        ),
      ),
      effect.none(),
      app_event.NoAppEvent,
    )

    SessionLoaded(result) ->
      case result {
        api.ApiSuccess(option.Some(session)) -> #(
          Model(..model, current_session_id: option.Some(session.id)),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.ApiSuccess(option.None) -> #(
          Model(..model, current_session_id: option.None),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.ApiFailure(_) | api.HttpFailure(_) -> #(
          model,
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    AccountSessionsLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            sessions: response.sessions,
            sessions_status: IdleSessions,
            sessions_loading_indicator: delayed_loading.finish(
              model.sessions_loading_indicator,
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            sessions_status: SessionsError(api.error_message(error)),
            sessions_loading_indicator: delayed_loading.finish(
              model.sessions_loading_indicator,
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            sessions_status: SessionsError("Could not load sessions."),
            sessions_loading_indicator: delayed_loading.finish(
              model.sessions_loading_indicator,
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    SessionsLoadingDelayElapsed(generation) -> #(
      Model(
        ..model,
        sessions_loading_indicator: delayed_loading.reveal(
          model.sessions_loading_indicator,
          generation,
        ),
      ),
      effect.none(),
      app_event.NoAppEvent,
    )

    AccountPasskeysLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            passkeys: response.passkeys,
            passkeys_status: IdlePasskeys,
            passkeys_loading_indicator: delayed_loading.finish(
              model.passkeys_loading_indicator,
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError(api.error_message(error)),
            passkeys_loading_indicator: delayed_loading.finish(
              model.passkeys_loading_indicator,
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            passkeys_status: PasskeysError("Could not load passkeys."),
            passkeys_loading_indicator: delayed_loading.finish(
              model.passkeys_loading_indicator,
            ),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    PasskeysLoadingDelayElapsed(generation) -> #(
      Model(
        ..model,
        passkeys_loading_indicator: delayed_loading.reveal(
          model.passkeys_loading_indicator,
          generation,
        ),
      ),
      effect.none(),
      app_event.NoAppEvent,
    )

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
              account: loadable.Loaded(account),
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
            api.finish_passkey_registration(
              request,
              FinishedPasskeyRegistration,
            ),
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
        api.ApiSuccess(_) -> {
          let #(passkeys_loading_indicator, delay_effect) =
            delayed_loading.start(
              model.passkeys_loading_indicator,
              PasskeysLoadingDelayElapsed,
            )
          #(
            Model(
              ..model,
              passkey_setup_status: PasskeySaved,
              passkeys_status: LoadingPasskeys,
              passkeys_loading_indicator:,
            ),
            effect.batch([
              api.list_account_passkeys(AccountPasskeysLoaded),
              delay_effect,
            ]),
            app_event.NoAppEvent,
          )
        }

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

    DeleteSessionSubmitted(id) -> {
      let request = account_session_dto.DeleteAccountSessionRequest(id:)
      #(
        Model(..model, sessions_status: DeletingSession(id)),
        api.delete_account_session(request, fn(result) {
          DeletedSession(id, result)
        }),
        app_event.NoAppEvent,
      )
    }

    DeletedSession(_id, result) ->
      case result {
        api.ApiSuccess(_) -> {
          let #(sessions_loading_indicator, delay_effect) =
            delayed_loading.start(
              model.sessions_loading_indicator,
              SessionsLoadingDelayElapsed,
            )
          #(
            Model(
              ..model,
              sessions_status: LoadingSessions,
              sessions_loading_indicator:,
            ),
            effect.batch([
              api.get_session(SessionLoaded),
              api.list_account_sessions(AccountSessionsLoaded),
              delay_effect,
            ]),
            app_event.RefreshSession,
          )
        }

        api.ApiFailure(error) -> #(
          Model(
            ..model,
            sessions_status: SessionsError(api.error_message(error)),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )

        api.HttpFailure(_) -> #(
          Model(
            ..model,
            sessions_status: SessionsError("Could not delete session."),
          ),
          effect.none(),
          app_event.NoAppEvent,
        )
      }

    DeletePasskeySubmitted(id) -> {
      let request = passkey_dto.DeleteAccountPasskeyRequest(id:)
      #(
        Model(..model, passkeys_status: DeletingPasskey(id)),
        api.delete_account_passkey(request, fn(result) {
          DeletedPasskey(id, result)
        }),
        app_event.NoAppEvent,
      )
    }

    DeletedPasskey(_id, result) ->
      case result {
        api.ApiSuccess(_) -> {
          let #(passkeys_loading_indicator, delay_effect) =
            delayed_loading.start(
              model.passkeys_loading_indicator,
              PasskeysLoadingDelayElapsed,
            )
          #(
            Model(
              ..model,
              passkeys_status: LoadingPasskeys,
              passkeys_loading_indicator:,
            ),
            effect.batch([
              api.list_account_passkeys(AccountPasskeysLoaded),
              delay_effect,
            ]),
            app_event.NoAppEvent,
          )
        }

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

    ToggleDangerZone -> #(
      Model(..model, danger_zone_expanded: !model.danger_zone_expanded),
      effect.none(),
      app_event.NoAppEvent,
    )

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
    html.main(
      [
        attribute.id("main-content"),
        attribute.attribute("tabindex", "-1"),
        attribute.class("app-shell app-shell--narrow"),
      ],
      [
        html.section([attribute.class("account-page")], [
          html.h1([attribute.class("account-page__title")], [
            html.text("Account"),
          ]),
          content(model, now),
        ]),
      ],
    ),
  ])
}

fn content(model: Model, now: Timestamp) -> Element(Msg) {
  case
    model.account,
    delayed_loading.is_visible(model.account_loading_indicator)
  {
    loadable.Loading, True ->
      html.p(
        [
          attribute.class("account-page__status"),
          attribute.attribute("role", "status"),
        ],
        [html.text("Loading account...")],
      )

    loadable.LoadError(message), _ ->
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

    loadable.NotLoaded, _ | loadable.Loading, False -> html.text("")

    loadable.Loaded(account), _ -> account_form(model, account, now)
  }
}

fn account_form(
  model: Model,
  account: account_dto.AccountResponse,
  now: Timestamp,
) -> Element(Msg) {
  html.div([attribute.class("account-page__panels")], [
    html.section([attribute.class("app-panel")], [
      html.h2([attribute.class("account-page__section-title")], [
        html.text("Account Info"),
      ]),
      account_row("Email", email_address_model.to_string(account.email)),
      account_row(
        "Joined",
        timestamp.to_rfc3339(account.joined_at, calendar.utc_offset),
      ),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h2([attribute.class("account-page__section-title")], [
        html.text("Account Settings"),
      ]),
      account_settings_form(model),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h2([attribute.class("account-page__section-title")], [
        html.text("Appearance"),
      ]),
      html.div([attribute.class("account-page__appearance")], [
        html.p([attribute.class("account-page__status")], [
          html.text("Choose a color theme, or follow your system setting."),
        ]),
        element.element(
          "glot-theme-picker",
          [attribute.class("account-page__theme-picker")],
          [],
        ),
      ]),
    ]),
    case should_show_passkey_section(model.passkey_supported) {
      True ->
        html.section([attribute.class("app-panel")], [
          html.h2([attribute.class("account-page__section-title")], [
            html.text("Passkeys"),
          ]),
          passkey_section(model, now),
        ])
      False -> html.text("")
    },
    html.section([attribute.class("app-panel")], [
      html.h2([attribute.class("account-page__section-title")], [
        html.text("Snippets"),
      ]),
      snippets_section(),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h2([attribute.class("account-page__section-title")], [
        html.text("Sessions"),
      ]),
      sessions_section(model, now),
    ]),
    html.section([attribute.class("app-panel")], [
      html.h2([attribute.class("account-page__section-title")], [
        html.text("Danger Zone"),
      ]),
      delete_account_section(
        account,
        model.status,
        model.danger_zone_expanded,
        now,
      ),
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

fn passkey_section(model: Model, now: Timestamp) -> Element(Msg) {
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

fn sessions_section(model: Model, now: Timestamp) -> Element(Msg) {
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

fn account_row(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("account-page__row")], [
    html.span([attribute.class("account-page__row-label")], [html.text(label)]),
    html.span([attribute.class("account-page__row-value")], [html.text(value)]),
  ])
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

fn delete_account_section(
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

fn passkey_button_text(passkey_setup_status: PasskeySetupStatus) -> String {
  case passkey_setup_status {
    StartingPasskeySetup -> "Preparing..."
    CreatingPasskey -> "Waiting for passkey..."
    SavingPasskey -> "Saving..."
    _ -> "Add passkey"
  }
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
