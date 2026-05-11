import gleam/int
import gleam/list
import gleam/option
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/user_dto
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

const page_limit = 25

pub type Model {
  Model(
    page: pagination_model.CursorPage(user_dto.UserSummaryResponse),
    search_filter: String,
    role_filter: String,
    account_state_filter: String,
    account_tier_filter: String,
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
  SearchFilterChanged(String)
  RoleFilterChanged(String)
  AccountStateFilterChanged(String)
  AccountTierFilterChanged(String)
  ApplyFilterClicked
  ClearFilterClicked
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
      search_filter: "",
      role_filter: "",
      account_state_filter: "",
      account_tier_filter: "",
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
        api.ApiSuccess(response) -> #(
          Model(..model, page: response.page, status: Ready),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, status: LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, status: LoadError("Could not load users.")),
          effect.none(),
        )
      }

    SearchFilterChanged(value) -> #(
      Model(..model, search_filter: value),
      effect.none(),
    )

    RoleFilterChanged(value) -> #(
      Model(..model, role_filter: value),
      effect.none(),
    )

    AccountStateFilterChanged(value) -> #(
      Model(..model, account_state_filter: value),
      effect.none(),
    )

    AccountTierFilterChanged(value) -> #(
      Model(..model, account_tier_filter: value),
      effect.none(),
    )

    ApplyFilterClicked -> load_initial(Model(..model, status: Loading))

    ClearFilterClicked ->
      case has_filters(model) {
        True ->
          load_initial(
            Model(
              ..model,
              search_filter: "",
              role_filter: "",
              account_state_filter: "",
              account_tier_filter: "",
              status: Loading,
            ),
          )
        False -> #(model, effect.none())
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
                html.text("Filters"),
              ]),
            ]),
          ]),
          filters_view(model),
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
          ]),
          status_view(model),
          users_table(model, now),
        ]),
      ]),
    ]),
  ])
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  let reset_page =
    pagination_model.InitialCursorPage(items: [], next_cursor: option.None)

  load_page(
    Model(..model, page: reset_page, status: Loading),
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
      user_dto.ListUsersRequest(
        pagination: pagination,
        email: filter_email(model.search_filter),
        username: filter_username(model.search_filter),
        id: filter_user_id(model.search_filter),
        role: filter_role(model.role_filter),
        account_state: filter_account_state(model.account_state_filter),
        account_tier: filter_account_tier(model.account_tier_filter),
      ),
      UsersLoaded,
    ),
  )
}

fn filters_view(model: Model) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy")], [
    html.div([attribute.class("admin-page__modal-grid")], [
      text_input(
        id: "admin-users-search",
        label: "Email, username, or id",
        placeholder: "exact email, username, or uuid",
        value: model.search_filter,
        on_input: SearchFilterChanged,
      ),
      select_input(
        id: "admin-users-role",
        label: "Role",
        value: model.role_filter,
        on_input: RoleFilterChanged,
        options: role_filter_options(),
      ),
      select_input(
        id: "admin-users-account-state",
        label: "Account status",
        value: model.account_state_filter,
        on_input: AccountStateFilterChanged,
        options: account_state_filter_options(),
      ),
      select_input(
        id: "admin-users-account-tier",
        label: "Tier",
        value: model.account_tier_filter,
        on_input: AccountTierFilterChanged,
        options: account_tier_filter_options(),
      ),
    ]),
    html.div([attribute.class("admin-page__policy-actions")], [
      html.button(
        [
          attribute.class("admin-page__button"),
          attribute.type_("button"),
          event.on_click(ApplyFilterClicked),
        ],
        [html.text("Apply")],
      ),
      html.button(
        [
          attribute.class("admin-page__button admin-page__button--secondary"),
          attribute.type_("button"),
          attribute.disabled(!has_filters(model)),
          event.on_click(ClearFilterClicked),
        ],
        [html.text("Clear")],
      ),
    ]),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready ->
      html.p([attribute.class("admin-page__status")], [
        html.text(""),
      ])
    Loading ->
      html.p([attribute.class("admin-page__status")], [
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
      html.div([attribute.class("admin-data-table__wrap")], [
        html.table([attribute.class("admin-data-table")], [
          html.thead([], [
            html.tr([], [
              table_heading("User"),
              table_heading("Role"),
              table_heading("Account"),
              table_heading("Tier"),
              table_heading("Joined"),
              table_heading("Open"),
            ]),
          ]),
          html.tbody([], { rows |> list.map(fn(user) { user_row(user, now) }) }),
        ]),
      ])
  }
}

fn user_row(
  user: user_dto.UserSummaryResponse,
  now: Timestamp,
) -> Element(Msg) {
  html.tr([], [
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("User"),
      html.span(
        [attribute.class("admin-data-table__value jobs-table__primary")],
        [
          html.text(user.username),
        ],
      ),
    ]),
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Role"),
      html.span([attribute.class(role_badge_class(user))], [
        html.text(role_text(user)),
      ]),
    ]),
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Account"),
      html.div([attribute.class("jobs-table__stack")], [
        html.span([attribute.class(account_state_badge_class(user))], [
          html.text(account_state_text(user)),
        ]),
      ]),
    ]),
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Tier"),
      html.div([attribute.class("jobs-table__stack")], [
        html.span(
          [attribute.class("admin-data-table__value jobs-table__secondary")],
          [
            html.text(account_tier_text(user)),
          ],
        ),
      ]),
    ]),
    html.td([attribute.class("admin-data-table__cell")], [
      cell_label("Joined"),
      html.span(
        [attribute.class("admin-data-table__value jobs-table__primary")],
        [
          html.text(timestamp_helpers.relative_label(user.created_at, now)),
        ],
      ),
    ]),
    html.td([attribute.class("admin-data-table__cell")], [
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
  html.th([attribute.class("admin-data-table__heading")], [html.text(text)])
}

fn cell_label(text: String) -> Element(Msg) {
  html.span([attribute.class("admin-data-table__label")], [html.text(text)])
}

fn text_input(
  id id: String,
  label label: String,
  placeholder placeholder: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.input([
      attribute.id(id),
      attribute.type_("text"),
      attribute.class("admin-page__input"),
      attribute.placeholder(placeholder),
      attribute.value(value),
      event.on_input(on_input),
    ]),
  ])
}

fn select_input(
  id id: String,
  label label: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
  options options: List(#(String, String)),
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.select(
      [
        attribute.id(id),
        attribute.class("admin-page__input"),
        attribute.value(value),
        event.on_input(on_input),
      ],
      options
        |> list.map(fn(option_entry) {
          let #(option_value, option_label) = option_entry

          html.option(
            [
              attribute.value(option_value),
              attribute.selected(option_value == value),
            ],
            option_label,
          )
        }),
    ),
  ])
}

fn role_filter_options() -> List(#(String, String)) {
  [
    #("", "Any role"),
    #(user_model.role_to_string(user_model.RegularUser), "User"),
    #(user_model.role_to_string(user_model.AdminUser), "Admin"),
  ]
}

fn account_state_filter_options() -> List(#(String, String)) {
  [
    #("", "Any status"),
    #(account_model.account_state_to_string(account_model.Active), "Active"),
    #(
      account_model.account_state_to_string(account_model.ReadOnly),
      "Read only",
    ),
    #(
      account_model.account_state_to_string(account_model.Suspended),
      "Suspended",
    ),
  ]
}

fn account_tier_filter_options() -> List(#(String, String)) {
  [
    #("", "Any tier"),
    #(account_model.account_tier_to_string(account_model.FreeTier), "Free"),
    #(
      account_model.account_tier_to_string(account_model.FreePlusTier),
      "FreePlus",
    ),
  ]
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
    account_model.FreeTier -> "Free"
    account_model.FreePlusTier -> "FreePlus"
  }
}

fn has_filters(model: Model) -> Bool {
  string.trim(model.search_filter) != ""
  || model.role_filter != ""
  || model.account_state_filter != ""
  || model.account_tier_filter != ""
}

fn filter_email(value: String) -> option.Option(String) {
  let trimmed = string.trim(value)

  case string.contains(trimmed, "@") {
    True -> option.Some(trimmed)
    False -> option.None
  }
}

fn filter_username(value: String) -> option.Option(String) {
  let trimmed = string.trim(value)

  case trimmed == "" || string.contains(trimmed, "@") {
    True -> option.None
    False ->
      case uuid.from_string(trimmed) {
        Ok(_) -> option.None
        Error(_) -> option.Some(trimmed)
      }
  }
}

fn filter_user_id(value: String) -> option.Option(uuid.Uuid) {
  let trimmed = string.trim(value)

  case uuid.from_string(trimmed) {
    Ok(id) -> option.Some(id)
    Error(_) -> option.None
  }
}

fn filter_role(value: String) -> option.Option(user_model.UserRole) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> user_model.role_from_string(trimmed)
  }
}

fn filter_account_state(
  value: String,
) -> option.Option(account_model.AccountState) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> account_model.account_state_from_string(trimmed)
  }
}

fn filter_account_tier(
  value: String,
) -> option.Option(account_model.AccountTier) {
  case string.trim(value) {
    "" -> option.None
    trimmed -> account_model.account_tier_from_string(trimmed)
  }
}
