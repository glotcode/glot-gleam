import gleam/int
import gleam/list
import gleam/option
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/user_dto
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

const page_limit = 25

pub type Model {
  Model(
    page: pagination_model.CursorPage(user_dto.UserSummaryResponse),
    status: Status,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type Msg {
  UsersLoaded(api.ApiResponse(user_dto.ListUsersResponse))
  NextPageClicked
  PreviousPageClicked
}

pub fn init() -> #(Model, Effect(Msg)) {
  #(
    Model(
      page: pagination_model.InitialCursorPage(
        items: [],
        next_cursor: option.None,
      ),
      status: NotLoaded,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> load_initial(model)
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UsersLoaded(result) ->
      case result {
        api.ApiSuccess(response) ->
          #(Model(page: response.page, status: Ready), effect.none())
        api.ApiFailure(error) ->
          #(Model(..model, status: LoadError(error.message)), effect.none())
        api.HttpFailure(_) ->
          #(Model(..model, status: LoadError("Could not load users.")), effect.none())
      }

    NextPageClicked ->
      case pagination_model.next_cursor(model.page) {
        option.Some(cursor) ->
          load_page(
            Model(..model, status: Loading),
            pagination_model.AfterPage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case pagination_model.previous_cursor(model.page) {
        option.Some(cursor) ->
          load_page(
            Model(..model, status: Loading),
            pagination_model.BeforePage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.page)
  let count_text = int.to_string(list.length(rows)) <> " users shown."

  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-jobs-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("Users"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "Review user accounts, account access state, and role assignments.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            pagination_button(
              "Previous",
              PreviousPageClicked,
              can_go_previous(model),
            ),
            pagination_button("Next", NextPageClicked, can_go_next(model)),
          ]),
        ]),
        html.div([attribute.class("admin-page__group")], [
          html.div([attribute.class("admin-page__group-header")], [
            html.div([], [
              html.h3([attribute.class("admin-page__group-title")], [
                html.text("Directory"),
              ]),
              html.p([attribute.class("admin-page__group-copy")], [
                html.text(count_text),
              ]),
            ]),
            html.div([attribute.class("admin-page__policy-actions")], [
              html.a(
                [
                  attribute.class(
                    "admin-page__button admin-page__button--secondary",
                  ),
                  route.href(route.Admin),
                ],
                [html.text("Back to admin")],
              ),
            ]),
          ]),
          status_view(model),
          users_table(model, now),
        ]),
      ]),
    ]),
  ])
}

fn load_initial(_model: Model) -> #(Model, Effect(Msg)) {
  let reset_page =
    pagination_model.InitialCursorPage(items: [], next_cursor: option.None)

  load_page(
    Model(page: reset_page, status: Loading),
    pagination_model.InitialPage(limit: page_limit),
  )
}

fn load_page(
  model: Model,
  pagination: pagination_model.CursorPagination,
) -> #(Model, Effect(Msg)) {
  #(
    model,
    api.get_admin_users(
      user_dto.ListUsersRequest(pagination: pagination),
      UsersLoaded,
    ),
  )
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready -> html.p([attribute.class("admin-page__status")], [
      html.text(""),
    ])
    Loading -> html.p([attribute.class("admin-page__status")], [
      html.text("Loading users..."),
    ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn users_table(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(model.page)

  case rows, model.status {
    [], Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading users..."),
      ])
    [], _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("No users were returned."),
      ])
    _, _ ->
      html.div([attribute.class("jobs-table")], [
        html.div([attribute.class("jobs-table__head")], [
          table_heading("User"),
          table_heading("Email"),
          table_heading("Role"),
          table_heading("Account"),
          table_heading("Joined"),
          table_heading("Open"),
        ]),
        html.div([attribute.class("jobs-table__body")], {
          rows |> list.map(fn(user) { user_row(user, now) })
        }),
      ])
  }
}

fn user_row(user: user_dto.UserSummaryResponse, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("jobs-table__row")], [
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("User"),
      html.div([attribute.class("jobs-table__stack")], [
        html.span([attribute.class("jobs-table__primary")], [
          html.text(user.username),
        ]),
        html.span([attribute.class("jobs-table__secondary")], [
          html.text(timestamp_helpers.relative_label(user.last_login_at, now)),
        ]),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("Email"),
      html.span([attribute.class("jobs-table__primary")], [
        html.text(email_address_model.to_string(user.email)),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("Role"),
      html.span([attribute.class(role_badge_class(user))], [
        html.text(role_text(user)),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("Account"),
      html.div([attribute.class("jobs-table__stack")], [
        html.span([attribute.class(account_state_badge_class(user))], [
          html.text(account_state_text(user)),
        ]),
        html.span([attribute.class("jobs-table__secondary")], [
          html.text(account_tier_text(user)),
        ]),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell")], [
      cell_label("Joined"),
      html.span([attribute.class("jobs-table__primary")], [
        html.text(timestamp_helpers.relative_label(user.created_at, now)),
      ]),
    ]),
    html.div([attribute.class("jobs-table__cell jobs-table__cell--actions")], [
      cell_label("Open"),
      html.a(
        [
          attribute.class("admin-page__button admin-page__button--secondary"),
          route.href(route.AdminUser(user.id)),
        ],
        [html.text("Open")],
      ),
    ]),
  ])
}

fn can_go_previous(model: Model) -> Bool {
  case pagination_model.previous_cursor(model.page) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn can_go_next(model: Model) -> Bool {
  case pagination_model.next_cursor(model.page) {
    option.Some(_) -> True
    option.None -> False
  }
}

fn pagination_button(label: String, msg: Msg, enabled: Bool) -> Element(Msg) {
  html.button(
    [
      attribute.class("admin-page__button admin-page__button--secondary"),
      attribute.attribute("type", "button"),
      attribute.disabled(!enabled),
      event.on_click(msg),
    ],
    [html.text(label)],
  )
}

fn table_heading(text: String) -> Element(Msg) {
  html.span([attribute.class("jobs-table__heading")], [html.text(text)])
}

fn cell_label(text: String) -> Element(Msg) {
  html.span([attribute.class("jobs-table__cell-label")], [html.text(text)])
}

fn role_text(user: user_dto.UserSummaryResponse) -> String {
  case user.role {
    user_model.AdminUser -> "Admin"
    user_model.RegularUser -> "User"
  }
}

fn role_badge_class(user: user_dto.UserSummaryResponse) -> String {
  case user.role {
    user_model.AdminUser -> "jobs-table__badge jobs-table__badge--running"
    user_model.RegularUser -> "jobs-table__badge jobs-table__badge--done"
  }
}

fn account_state_text(user: user_dto.UserSummaryResponse) -> String {
  case user.account_state {
    account_model.Active -> "Active"
    account_model.ReadOnly -> "Read only"
    account_model.Suspended -> "Suspended"
  }
}

fn account_state_badge_class(user: user_dto.UserSummaryResponse) -> String {
  case user.account_state {
    account_model.Active -> "jobs-table__badge jobs-table__badge--done"
    account_model.ReadOnly -> "jobs-table__badge jobs-table__badge--pending"
    account_model.Suspended -> "jobs-table__badge jobs-table__badge--failed"
  }
}

fn account_tier_text(user: user_dto.UserSummaryResponse) -> String {
  case user.account_tier {
    account_model.FreeTier -> "Free tier"
    account_model.FreePlusTier -> "FreePlus tier"
  }
}
