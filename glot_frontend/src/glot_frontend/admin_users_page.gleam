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
import glot_frontend/admin_table
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/loadable
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

const page_limit = 25

pub type Model {
  Model(
    page: loadable.Loadable(pagination_model.CursorPage(user_dto.UserSummaryResponse)),
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
  case model.page {
    loadable.NotLoaded -> load_initial(model)
    loadable.Loading | loadable.Loaded(_) | loadable.LoadError(_) ->
      #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UsersLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(..model, page: loadable.Loaded(response.page)),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(..model, page: loadable.LoadError(error.message)),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(..model, page: loadable.LoadError("Could not load users.")),
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
      case pagination_model.next_cursor(current_page(model)) {
        option.Some(cursor) ->
          load_page(
            Model(..model, page: loadable.Loading),
            pagination_model.AfterPage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }

    PreviousPageClicked ->
      case pagination_model.previous_cursor(current_page(model)) {
        option.Some(cursor) ->
          load_page(
            Model(..model, page: loadable.Loading),
            pagination_model.BeforePage(cursor: cursor, limit: page_limit),
          )
        option.None -> #(model, effect.none())
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(current_page(model))
  let count_text = int.to_string(list.length(rows)) <> " users shown."

  admin_ui.page_with_panel_class(
    panel_class: "admin-jobs-page",
    title: "Users",
    intro: "Review user accounts, account access state, and role assignments.",
    actions:
      admin_ui.cursor_pagination_actions(
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
          status_view(model),
          users_table(model, now),
      ]),
    ],
  )
}

fn load_initial(model: Model) -> #(Model, Effect(Msg)) {
  load_page(Model(..model, page: loadable.Loading), pagination_model.InitialPage(limit: page_limit))
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
    html.div([attribute.class("admin-page__actions")], [
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

fn status_view(model: Model) -> Element(Msg) {
  loadable.fold(
    model.page,
    admin_ui.status(""),
    admin_ui.status("Loading users..."),
    fn(_) { admin_ui.status("") },
    admin_ui.error_status,
  )
}

fn users_table(model: Model, now: Timestamp) -> Element(Msg) {
  loadable.fold(
    model.page,
    admin_ui.empty_state("No users were returned."),
    admin_ui.empty_state("Loading users..."),
    fn(page) {
      case pagination_model.items(page) {
        [] -> admin_ui.empty_state("No users were returned.")
        rows ->
          admin_table.table(user_columns(), {
            rows |> list.map(fn(user) { user_row(user, now) })
          })
      }
    },
    fn(_) { admin_ui.empty_state("No users were returned.") },
  )
}

fn user_row(
  user: user_dto.UserSummaryResponse,
  now: Timestamp,
) -> Element(Msg) {
  admin_table.row([
    admin_table.cell(user_column(), [admin_table.primary_value(user.username)]),
    admin_table.cell(role_column(), [role_badge(user)]),
    admin_table.cell(account_column(), [
      admin_table.stack([account_state_badge(user)]),
    ]),
    admin_table.cell(tier_column(), [
      admin_table.stack([admin_table.secondary_value(account_tier_text(user))]),
    ]),
    admin_table.cell(joined_column(), [
      admin_table.primary_value(timestamp_helpers.relative_label(
        user.created_at,
        now,
      )),
    ]),
    admin_table.cell(open_column(), [
      admin_ui.secondary_link([route.href(route.AdminUser(user.id))], "Open"),
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
  admin_table.action_column("Open")
}

fn current_page(
  model: Model,
) -> pagination_model.CursorPage(user_dto.UserSummaryResponse) {
  case model.page {
    loadable.Loaded(page) -> page
    loadable.NotLoaded | loadable.Loading | loadable.LoadError(_) ->
      pagination_model.InitialCursorPage(items: [], next_cursor: option.None)
  }
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
