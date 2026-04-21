import gleam/option
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import glot_core/auth/account_dto
import glot_core/email/email_address_model
import glot_frontend/api
import glot_frontend/route
import glot_frontend/top_bar
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

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
  Saved
  Error(String)
}

pub type Msg {
  AccountLoaded(api.ApiResponse(account_dto.AccountResponse))
  UsernameChanged(String)
  UsernameSubmitted
  AccountUpdated(api.ApiResponse(account_dto.AccountResponse))
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(account: option.None, username: "", status: Loading),
    api.get_account(AccountLoaded),
  )
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
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
          )
        }

        api.ApiFailure(error) -> #(
          Model(..model, status: Error(error.message)),
          effect.none(),
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: Error("Could not load account.")),
          effect.none(),
        )
      }

    UsernameChanged(username) -> #(
      Model(..model, username: username, status: Idle),
      effect.none(),
    )

    UsernameSubmitted -> {
      let username = string.trim(model.username)

      case username == "" {
        True -> #(
          Model(
            ..model,
            username: username,
            status: Error("Username is required."),
          ),
          effect.none(),
        )

        False -> {
          let request = account_dto.UpdateAccountRequest(username:)
          #(
            Model(..model, username: username, status: Saving),
            api.update_account(request, AccountUpdated),
          )
        }
      }
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
          )
        }

        api.ApiFailure(error) -> #(
          Model(..model, status: Error(error.message)),
          effect.none(),
        )

        api.HttpFailure(_) -> #(
          Model(..model, status: Error("Could not update account.")),
          effect.none(),
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
      html.section([attribute.class("app-panel account-page")], [
        html.h2([attribute.class("account-page__title")], [
          html.text("Account settings"),
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
  html.form(
    [
      attribute.class("account-page__form"),
      event.on_submit(fn(_) { UsernameSubmitted }),
    ],
    [
      account_row("Email", email_address_model.to_string(account.email)),
      account_row(
        "Joined",
        timestamp.to_rfc3339(account.joined_at, calendar.utc_offset),
      ),
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
          attribute.disabled(model.status == Saving),
          attribute.class("account-page__button"),
        ],
        [html.text(button_text(model.status))],
      ),
    ],
  )
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
    Error(message) ->
      html.p(
        [attribute.class("account-page__status account-page__status--error")],
        [
          html.text(message),
        ],
      )
  }
}

fn button_text(status: Status) -> String {
  case status {
    Saving -> "Saving..."
    _ -> "Save username"
  }
}
