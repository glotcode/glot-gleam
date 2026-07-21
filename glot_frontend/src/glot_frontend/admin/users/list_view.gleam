import gleam/int
import gleam/list
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/user_dto
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/helpers/timestamp_helpers
import glot_core/pagination_model
import glot_core/route
import glot_frontend/admin/ui/cursor_page as admin_cursor_page
import glot_frontend/admin/ui/filter as admin_filter
import glot_frontend/admin/ui/form as admin_form
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/admin/ui/pagination as admin_pagination
import glot_frontend/admin/ui/status as admin_status
import glot_frontend/admin/ui/table as admin_table
import glot_frontend/admin/users/list_filter
import glot_frontend/admin/users/list_message.{
  type Msg, AccountStateFilterChanged, AccountTierFilterChanged,
  ApplyFilterClicked, ClearFilterClicked, NextPageClicked, PreviousPageClicked,
  RoleFilterChanged, SearchFilterChanged,
}

import glot_frontend/admin/users/list_model.{type Model}
import glot_web/route as web_route
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  let rows = pagination_model.items(current_page(model))
  let count_text = int.to_string(list.length(rows)) <> " users shown."

  admin_layout.page_with_panel_class(
    panel_class: "admin-jobs-page",
    title: "Users",
    intro: "Review user accounts, account access state, and role assignments.",
    actions: admin_pagination.cursor_pagination_actions(
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
        admin_status.loadable_status(model.page, "Loading users..."),
        users_table(model, now),
      ]),
    ],
  )
}

fn filters_view(model: Model) -> Element(Msg) {
  admin_filter.filter_surface([], [
    admin_filter.filter_field_grid([attribute.class("admin-page__modal-grid")], [
      admin_form.text_input_with_attrs(
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
      admin_form.select_input_with_attrs(
        label: "Role",
        value: model.role_filter,
        on_input: RoleFilterChanged,
        options: role_filter_options(),
        help: "",
        field_class: "",
        select_class: "",
        select_attributes: [attribute.id("admin-users-role")],
      ),
      admin_form.select_input_with_attrs(
        label: "Account status",
        value: model.account_state_filter,
        on_input: AccountStateFilterChanged,
        options: account_state_filter_options(),
        help: "",
        field_class: "",
        select_class: "",
        select_attributes: [attribute.id("admin-users-account-state")],
      ),
      admin_form.select_input_with_attrs(
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
    admin_filter.filter_actions([], [
      html.button(
        [
          attribute.class("admin-page__button"),
          attribute.type_("button"),
          event.on_click(ApplyFilterClicked),
        ],
        [html.text("Apply")],
      ),
      admin_layout.secondary_button(
        [
          attribute.type_("button"),
          attribute.disabled(!list_filter.has_filters(model)),
          event.on_click(ClearFilterClicked),
        ],
        "Clear",
      ),
    ]),
  ])
}

fn users_table(model: Model, now: Timestamp) -> Element(Msg) {
  admin_pagination.loadable_cursor_page_content(
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
      web_route.href(route.Admin(route.AdminUser(user.id))),
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
      admin_layout.badge(role_text(user), admin_layout.WarningTone)
    user_model.RegularUser ->
      admin_layout.badge(role_text(user), admin_layout.SuccessTone)
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
      admin_layout.badge(account_state_text(user), admin_layout.SuccessTone)
    account_model.ReadOnly ->
      admin_layout.badge(account_state_text(user), admin_layout.InfoTone)
    account_model.Suspended ->
      admin_layout.badge(account_state_text(user), admin_layout.DangerTone)
  }
}

fn account_tier_text(user: user_dto.UserSummaryResponse) -> String {
  case user.account_tier {
    account_model.FreeTier -> "Free"
    account_model.FreePlusTier -> "FreePlus"
  }
}
