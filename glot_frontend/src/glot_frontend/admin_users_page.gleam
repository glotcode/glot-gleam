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
import glot_frontend/admin_cursor_page
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_core/loadable
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

const page_limit = 25

pub type Model {
  Model(
    page: loadable.Loadable(
      pagination_model.CursorPage(user_dto.UserSummaryResponse),
    ),
    search_filter: String,
    role_filter: String,
    account_state_filter: String,
    account_tier_filter: String,
  )
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
      page: loadable.NotLoaded,
      search_filter: "",
      role_filter: "",
      account_state_filter: "",
      account_tier_filter: "",
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case
    admin_cursor_page.ensure_loaded(
      model.page,
      load_page(
        Model(..model, page: loadable.Loading),
        pagination_model.InitialPage(limit: page_limit),
      ).1,
    )
  {
    #(page, next_effect) -> #(Model(..model, page: page), next_effect)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UsersLoaded(result) ->
      case result {
        _ -> #(
          Model(
            ..model,
            page: admin_cursor_page.page_from_response(
              result,
              fn(response) { response.page },
              "Could not load users.",
            ),
          ),
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

    ApplyFilterClicked -> load_initial(model)

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
            ),
          )
        False -> #(model, effect.none())
      }

    NextPageClicked ->
      admin_cursor_page.next_page(
        model,
        model.page,
        fn(model, page) { Model(..model, page: page) },
        load_page,
        page_limit,
      )

    PreviousPageClicked ->
      admin_cursor_page.previous_page(
        model,
        model.page,
        fn(model, page) { Model(..model, page: page) },
        load_page,
        page_limit,
      )
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(current_page(model))
  let count_text = int.to_string(list.length(rows)) <> " users shown."

  admin_ui.page_with_panel_class(
    panel_class: "admin-jobs-page",
    title: "Users",
    intro: "Review user accounts, account access state, and role assignments.",
    actions: admin_ui.cursor_pagination_actions(
      current_page(model),
      PreviousPageClicked,
      NextPageClicked,
    ),
    content: [
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
        admin_ui.loadable_status(model.page, "Loading users..."),
        users_table(model, now),
      ]),
    ],
  )
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  admin_cursor_page.load_initial(
    model,
    fn(model, page) { Model(..model, page: page) },
    load_page,
    page_limit,
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
  admin_ui.filter_surface([], [
    admin_ui.filter_field_grid([attribute.class("admin-page__modal-grid")], [
      admin_ui.text_input_with_attrs(
        label: "Email, username, or id",
        help: "",
        value: model.search_filter,
        placeholder: "exact email, username, or uuid",
        input_type: "text",
        field_class: "",
        input_class: "",
        input_attributes: [attribute.id("admin-users-search")],
        on_input: SearchFilterChanged,
      ),
      admin_ui.select_input_with_attrs(
        label: "Role",
        value: model.role_filter,
        on_input: RoleFilterChanged,
        options: role_filter_options(),
        help: "",
        field_class: "",
        select_class: "",
        select_attributes: [attribute.id("admin-users-role")],
      ),
      admin_ui.select_input_with_attrs(
        label: "Account status",
        value: model.account_state_filter,
        on_input: AccountStateFilterChanged,
        options: account_state_filter_options(),
        help: "",
        field_class: "",
        select_class: "",
        select_attributes: [attribute.id("admin-users-account-state")],
      ),
      admin_ui.select_input_with_attrs(
        label: "Tier",
        value: model.account_tier_filter,
        on_input: AccountTierFilterChanged,
        options: account_tier_filter_options(),
        help: "",
        field_class: "",
        select_class: "",
        select_attributes: [attribute.id("admin-users-account-tier")],
      ),
    ]),
    admin_ui.filter_actions([], [
      html.button(
        [
          attribute.class("admin-page__button"),
          attribute.type_("button"),
          event.on_click(ApplyFilterClicked),
        ],
        [html.text("Apply")],
      ),
      admin_ui.secondary_button(
        [
          attribute.type_("button"),
          attribute.disabled(!has_filters(model)),
          event.on_click(ClearFilterClicked),
        ],
        "Clear",
      ),
    ]),
  ])
}

fn users_table(model: Model, now: Timestamp) -> Element(Msg) {
  admin_ui.loadable_cursor_page_content(
    model.page,
    "Loading users...",
    "No users were returned.",
    fn(rows) {
      admin_table.table(user_columns(), {
        rows |> list.map(fn(user) { user_row(user, now) })
      })
    },
  )
}

fn user_row(
  user: user_dto.UserSummaryResponse,
  now: Timestamp,
) -> Element(Msg) {
  admin_table.row([
    admin_table.primary_cell(user_column(), user.username),
    admin_table.cell(role_column(), [role_badge(user)]),
    admin_table.cell(account_column(), [
      admin_table.stack([account_state_badge(user)]),
    ]),
    admin_table.secondary_cell(tier_column(), account_tier_text(user)),
    admin_table.primary_cell(
      joined_column(),
      timestamp_helpers.relative_label(user.created_at, now),
    ),
    admin_table.open_link_cell([
      route.href(route.Admin(route.AdminUser(user.id))),
    ]),
  ])
}

fn user_columns() -> List(admin_table.Column) {
  [
    user_column(),
    role_column(),
    account_column(),
    tier_column(),
    joined_column(),
    open_column(),
  ]
}

fn user_column() -> admin_table.Column {
  admin_table.column("User")
}

fn role_column() -> admin_table.Column {
  admin_table.fit_column("Role")
}

fn account_column() -> admin_table.Column {
  admin_table.fit_column("Account")
}

fn tier_column() -> admin_table.Column {
  admin_table.column("Tier")
}

fn joined_column() -> admin_table.Column {
  admin_table.fit_column("Joined at")
}

fn open_column() -> admin_table.Column {
  admin_table.open_column()
}

fn current_page(
  model: Model,
) -> pagination_model.CursorPage(user_dto.UserSummaryResponse) {
  admin_cursor_page.current_page(model.page)
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

fn role_badge(user: user_dto.UserSummaryResponse) -> Element(Msg) {
  case user.role {
    user_model.AdminUser ->
      admin_ui.badge(role_text(user), admin_ui.WarningTone)
    user_model.RegularUser ->
      admin_ui.badge(role_text(user), admin_ui.SuccessTone)
  }
}

fn account_state_text(user: user_dto.UserSummaryResponse) -> String {
  case user.account_state {
    account_model.Active -> "Active"
    account_model.ReadOnly -> "Read only"
    account_model.Suspended -> "Suspended"
  }
}

fn account_state_badge(user: user_dto.UserSummaryResponse) -> Element(Msg) {
  case user.account_state {
    account_model.Active ->
      admin_ui.badge(account_state_text(user), admin_ui.SuccessTone)
    account_model.ReadOnly ->
      admin_ui.badge(account_state_text(user), admin_ui.InfoTone)
    account_model.Suspended ->
      admin_ui.badge(account_state_text(user), admin_ui.DangerTone)
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
