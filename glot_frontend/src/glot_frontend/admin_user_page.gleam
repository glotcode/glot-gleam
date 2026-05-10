import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/user_dto
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/timestamp_helpers
import glot_core/route
import glot_frontend/api
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import youid/uuid

pub type Model {
  Model(
    id: uuid.Uuid,
    user: option.Option(UserEditor),
    status: Status,
  )
}

pub type Status {
  NotLoaded
  Loading
  Ready
  LoadError(String)
}

pub type UserEditor {
  UserEditor(
    id: uuid.Uuid,
    account_id: uuid.Uuid,
    email: email_address_model.EmailAddress,
    saved: UserFields,
    draft: UserFields,
    metadata: UserMetadata,
    state: EditorState,
  )
}

pub type UserFields {
  UserFields(
    username: String,
    role: user_model.UserRole,
    account_state: account_model.AccountState,
    account_state_reason: String,
    account_tier: account_model.AccountTier,
  )
}

pub type UserMetadata {
  UserMetadata(
    delete_job_id: option.Option(uuid.Uuid),
    delete_scheduled_at: option.Option(Timestamp),
    last_login_at: Timestamp,
    created_at: Timestamp,
    updated_at: Timestamp,
  )
}

pub type EditorState {
  Idle
  Saving
  Saved
  SaveError(String)
}

pub type Msg {
  UserLoaded(api.ApiResponse(user_dto.GetUserResponse))
  UsernameChanged(String)
  RoleChanged(String)
  AccountStateChanged(String)
  AccountStateReasonChanged(String)
  AccountTierChanged(String)
  ResetClicked
  SaveClicked
  SaveFinished(api.ApiResponse(user_dto.UpdateUserResponse))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(Model(id: id, user: option.None, status: NotLoaded), effect.none())
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case model.status {
    NotLoaded -> #(
      Model(..model, status: Loading),
      api.get_admin_user(user_dto.GetUserRequest(id: model.id), UserLoaded),
    )
    Loading | Ready | LoadError(_) -> #(model, effect.none())
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            user: option.Some(editor_from_response(response.user)),
            status: Ready,
          ),
          effect.none(),
        )
        api.ApiFailure(error) ->
          #(Model(..model, status: LoadError(error.message)), effect.none())
        api.HttpFailure(_) ->
          #(Model(..model, status: LoadError("Could not load user.")), effect.none())
      }

    UsernameChanged(value) -> #(
      update_editor(model, fn(editor) {
        UserEditor(
          ..editor,
          draft: UserFields(..editor.draft, username: value),
          state: Idle,
        )
      }),
      effect.none(),
    )

    RoleChanged(value) ->
      case user_model.role_from_string(value) {
        option.Some(role) -> #(
          update_editor(model, fn(editor) {
            UserEditor(
              ..editor,
              draft: UserFields(..editor.draft, role: role),
              state: Idle,
            )
          }),
          effect.none(),
        )
        option.None -> #(model, effect.none())
      }

    AccountStateChanged(value) ->
      case account_model.account_state_from_string(value) {
        option.Some(account_state) -> #(
          update_editor(model, fn(editor) {
            let next_reason = case account_state {
              account_model.Active -> ""
              account_model.ReadOnly | account_model.Suspended ->
                editor.draft.account_state_reason
            }

            UserEditor(
              ..editor,
              draft: UserFields(
                ..editor.draft,
                account_state: account_state,
                account_state_reason: next_reason,
              ),
              state: Idle,
            )
          }),
          effect.none(),
        )
        option.None -> #(model, effect.none())
      }

    AccountStateReasonChanged(value) -> #(
      update_editor(model, fn(editor) {
        UserEditor(
          ..editor,
          draft: UserFields(..editor.draft, account_state_reason: value),
          state: Idle,
        )
      }),
      effect.none(),
    )

    AccountTierChanged(value) ->
      case account_model.account_tier_from_string(value) {
        option.Some(account_tier) -> #(
          update_editor(model, fn(editor) {
            UserEditor(
              ..editor,
              draft: UserFields(..editor.draft, account_tier: account_tier),
              state: Idle,
            )
          }),
          effect.none(),
        )
        option.None -> #(model, effect.none())
      }

    ResetClicked -> #(
      update_editor(model, fn(editor) {
        UserEditor(..editor, draft: editor.saved, state: Idle)
      }),
      effect.none(),
    )

    SaveClicked ->
      case model.user {
        option.None -> #(model, effect.none())
        option.Some(editor) ->
          case editor_to_request(editor) {
            Ok(request) -> #(
              update_editor(model, fn(current) {
                UserEditor(..current, state: Saving)
              }),
              api.update_admin_user(request, SaveFinished),
            )
            Error(message) -> #(
              update_editor(model, fn(current) {
                UserEditor(..current, state: SaveError(message))
              }),
              effect.none(),
            )
          }
      }

    SaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            user: option.Some(editor_from_response(response.user)),
            status: Ready,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          update_editor(model, fn(editor) {
            UserEditor(..editor, state: SaveError(error.message))
          }),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          update_editor(model, fn(editor) {
            UserEditor(..editor, state: SaveError("Could not update user."))
          }),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("app-page")], [
    html.div([attribute.class("app-page__screen-glow")], []),
    html.main([attribute.class("app-shell")], [
      html.section([attribute.class("app-panel admin-page admin-job-page")], [
        html.div([attribute.class("admin-page__header")], [
          html.div([], [
            html.h2([attribute.class("admin-page__title")], [
              html.text("User detail"),
            ]),
            html.p([attribute.class("admin-page__status")], [
              html.text(
                "Review account access and edit persisted user and account settings.",
              ),
            ]),
          ]),
          html.div([attribute.class("admin-page__policy-actions")], [
            html.a(
              [
                attribute.class(
                  "admin-page__button admin-page__button--secondary",
                ),
                route.href(route.AdminUsers),
              ],
              [html.text("Back to users")],
            ),
          ]),
        ]),
        status_view(model),
        detail_view(model, now),
      ]),
    ]),
  ])
}

fn status_view(model: Model) -> Element(Msg) {
  case model.status {
    NotLoaded | Ready -> html.p([attribute.class("admin-page__status")], [
      html.text(""),
    ])
    Loading -> html.p([attribute.class("admin-page__status")], [
      html.text("Loading user..."),
    ])
    LoadError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn detail_view(model: Model, now: Timestamp) -> Element(Msg) {
  case model.user, model.status {
    option.None, Loading ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("Loading user..."),
      ])
    option.None, _ ->
      html.div([attribute.class("admin-page__empty")], [
        html.text("This user could not be loaded."),
      ])
    option.Some(editor), _ -> user_view(editor, now)
  }
}

fn user_view(editor: UserEditor, now: Timestamp) -> Element(Msg) {
  html.div([attribute.class("admin-job-page__content")], [
    html.div([attribute.class("admin-job-page__summary-grid")], [
      summary_card("Role", role_text(editor.draft.role)),
      summary_card("Access", account_state_text(editor.draft.account_state)),
      summary_card(
        "Last login",
        timestamp_helpers.relative_label(editor.metadata.last_login_at, now),
      ),
    ]),
    html.div([attribute.class("admin-page__group")], [
      html.div([attribute.class("admin-page__group-header")], [
        html.h3([attribute.class("admin-page__group-title")], [
          html.text("Metadata"),
        ]),
        html.p([attribute.class("admin-page__group-copy")], [
          html.text("Identifiers and read-only account attributes."),
        ]),
      ]),
      html.div([attribute.class("admin-job-page__detail-grid")], [
        detail_item("User ID", uuid.to_string(editor.id)),
        detail_item("Account ID", uuid.to_string(editor.account_id)),
        detail_item("Email", email_address_model.to_string(editor.email)),
        detail_item("Delete job ID", optional_uuid(editor.metadata.delete_job_id)),
        detail_item(
          "Delete scheduled at",
          optional_timestamp(editor.metadata.delete_scheduled_at),
        ),
        detail_item("Created at", format_timestamp(editor.metadata.created_at)),
        detail_item("Updated at", format_timestamp(editor.metadata.updated_at)),
      ]),
    ]),
    html.div([attribute.class("admin-page__group")], [
      html.div([attribute.class("admin-page__group-header")], [
        html.h3([attribute.class("admin-page__group-title")], [
          html.text("Editable settings"),
        ]),
        html.p([attribute.class("admin-page__group-copy")], [
          html.text(
            "Changes are persisted to the user and account records for this login identity.",
          ),
        ]),
      ]),
      edit_form(editor),
    ]),
  ])
}

fn edit_form(editor: UserEditor) -> Element(Msg) {
  html.form(
    [
      attribute.class("admin-page__policy"),
      event.on_submit(fn(_) { SaveClicked }),
    ],
    [
      html.div([attribute.class("admin-page__modal-grid")], [
        text_input(
          id: "admin-user-username",
          label: "Username",
          value: editor.draft.username,
          on_input: UsernameChanged,
        ),
        select_input(
          id: "admin-user-role",
          label: "Role",
          value: user_model.role_to_string(editor.draft.role),
          on_input: RoleChanged,
          options: role_options(),
        ),
        select_input(
          id: "admin-user-account-state",
          label: "Account state",
          value: account_model.account_state_to_string(editor.draft.account_state),
          on_input: AccountStateChanged,
          options: account_state_options(),
        ),
        select_input(
          id: "admin-user-account-tier",
          label: "Account tier",
          value: account_model.account_tier_to_string(editor.draft.account_tier),
          on_input: AccountTierChanged,
          options: account_tier_options(),
        ),
        text_input(
          id: "admin-user-account-state-reason",
          label: "Account state reason",
          value: editor.draft.account_state_reason,
          on_input: AccountStateReasonChanged,
        ),
      ]),
      save_status(editor.state),
      html.div([attribute.class("admin-page__policy-actions")], [
        html.button(
          [
            attribute.type_("button"),
            attribute.class("admin-page__button admin-page__button--secondary"),
            attribute.disabled(editor.state == Saving || !is_dirty(editor)),
            event.on_click(ResetClicked),
          ],
          [html.text("Reset")],
        ),
        html.button(
          [
            attribute.type_("submit"),
            attribute.class("admin-page__button"),
            attribute.disabled(editor.state == Saving),
          ],
          [html.text(save_button_text(editor.state))],
        ),
      ]),
    ],
  )
}

fn save_status(state: EditorState) -> Element(Msg) {
  case state {
    Idle -> html.p([attribute.class("admin-page__status")], [html.text("")])
    Saving -> html.p([attribute.class("admin-page__status")], [
      html.text("Saving user..."),
    ])
    Saved -> html.p([attribute.class("admin-page__status")], [
      html.text("User updated."),
    ])
    SaveError(message) ->
      html.p([attribute.class("admin-page__status admin-page__status--error")], [
        html.text(message),
      ])
  }
}

fn save_button_text(state: EditorState) -> String {
  case state {
    Saving -> "Saving..."
    Idle | Saved | SaveError(_) -> "Save user"
  }
}

fn update_editor(model: Model, update: fn(UserEditor) -> UserEditor) -> Model {
  case model.user {
    option.Some(editor) -> Model(..model, user: option.Some(update(editor)))
    option.None -> model
  }
}

fn editor_from_response(user: user_dto.UserDetailResponse) -> UserEditor {
  let fields =
    UserFields(
      username: user.username,
      role: user.role,
      account_state: user.account_state,
      account_state_reason: option.unwrap(user.account_state_reason, ""),
      account_tier: user.account_tier,
    )

  UserEditor(
    id: user.id,
    account_id: user.account_id,
    email: user.email,
    saved: fields,
    draft: fields,
    metadata: UserMetadata(
      delete_job_id: user.delete_job_id,
      delete_scheduled_at: user.delete_scheduled_at,
      last_login_at: user.last_login_at,
      created_at: user.created_at,
      updated_at: user.updated_at,
    ),
    state: Idle,
  )
}

fn editor_to_request(editor: UserEditor) -> Result(user_dto.UpdateUserRequest, String) {
  let username = string.trim(editor.draft.username)

  use _ <- result.try(user_model.validate_username(username))

  Ok(user_dto.UpdateUserRequest(
    id: editor.id,
    username: username,
    role: editor.draft.role,
    account_state: editor.draft.account_state,
    account_state_reason: account_state_reason_value(
      editor.draft.account_state,
      editor.draft.account_state_reason,
    ),
    account_tier: editor.draft.account_tier,
  ))
}

fn account_state_reason_value(
  account_state: account_model.AccountState,
  value: String,
) -> option.Option(String) {
  case account_state {
    account_model.Active -> option.None
    account_model.ReadOnly | account_model.Suspended ->
      case string.trim(value) {
        "" -> option.None
        trimmed -> option.Some(trimmed)
      }
  }
}

fn is_dirty(editor: UserEditor) -> Bool {
  editor.saved != editor.draft
}

fn summary_card(title: String, value: String) -> Element(Msg) {
  html.article(
    [attribute.class("admin-page__policy admin-job-page__summary-card")],
    [
      html.span([attribute.class("admin-job-page__eyebrow")], [html.text(title)]),
      html.strong([attribute.class("admin-job-page__summary-value")], [
        html.text(value),
      ]),
    ],
  )
}

fn detail_item(label: String, value: String) -> Element(Msg) {
  html.div([attribute.class("admin-page__policy admin-job-page__detail-item")], [
    html.span([attribute.class("admin-job-page__eyebrow")], [html.text(label)]),
    html.span([attribute.class("admin-job-page__detail-value")], [
      html.text(value),
    ]),
  ])
}

fn text_input(
  id id: String,
  label label: String,
  value value: String,
  on_input on_input: fn(String) -> Msg,
) -> Element(Msg) {
  html.label([attribute.class("admin-page__field")], [
    html.span([attribute.class("admin-page__field-label")], [html.text(label)]),
    html.input([
      attribute.id(id),
      attribute.type_("text"),
      attribute.class("admin-page__input"),
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
      list.map(options, fn(option_item) {
        let #(option_value, option_label) = option_item
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

fn role_options() -> List(#(String, String)) {
  [
    #(user_model.role_to_string(user_model.RegularUser), "User"),
    #(user_model.role_to_string(user_model.AdminUser), "Admin"),
  ]
}

fn account_state_options() -> List(#(String, String)) {
  [
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

fn account_tier_options() -> List(#(String, String)) {
  [
    #(account_model.account_tier_to_string(account_model.FreeTier), "Free"),
    #(
      account_model.account_tier_to_string(account_model.FreePlusTier),
      "FreePlus",
    ),
  ]
}

fn role_text(role: user_model.UserRole) -> String {
  case role {
    user_model.RegularUser -> "User"
    user_model.AdminUser -> "Admin"
  }
}

fn account_state_text(account_state: account_model.AccountState) -> String {
  case account_state {
    account_model.Active -> "Active"
    account_model.ReadOnly -> "Read only"
    account_model.Suspended -> "Suspended"
  }
}

fn optional_uuid(value: option.Option(uuid.Uuid)) -> String {
  case value {
    option.Some(id) -> uuid.to_string(id)
    option.None -> "None"
  }
}

fn optional_timestamp(value: option.Option(Timestamp)) -> String {
  case value {
    option.Some(timestamp) -> format_timestamp(timestamp)
    option.None -> "None"
  }
}

fn format_timestamp(value: Timestamp) -> String {
  timestamp.to_rfc3339(value, calendar.utc_offset)
}
