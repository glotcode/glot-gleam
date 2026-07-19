import gleam/dynamic/decode
import gleam/option
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_core/admin/account_dto
import glot_core/admin/user_dto
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_core/helpers/timestamp_helpers
import glot_core/route
import glot_core/validation_error
import glot_frontend/admin_format
import glot_frontend/admin_ui
import glot_frontend/api
import glot_frontend/app_dialog
import glot_core/loadable
import glot_frontend/mutation
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import modem
import youid/uuid

const delete_dialog_id = "admin-user-page-delete-dialog"

pub type Model {
  Model(
    id: uuid.Uuid,
    user: loadable.Loadable(UserEditor),
    pending_delete: option.Option(UserEditor),
    delete_state: DeleteState,
  )
}

pub type DeleteState {
  DeleteIdle
  Deleting
}

pub type UserEditor {
  UserEditor(
    id: uuid.Uuid,
    account_id: uuid.Uuid,
    email: email_address_model.EmailAddress,
    saved: UserFields,
    draft: UserFields,
    metadata: UserMetadata,
    state: mutation.MutationState,
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

pub type Msg {
  UserLoaded(api.ApiResponse(user_dto.GetUserResponse))
  UsernameChanged(String)
  RoleChanged(String)
  AccountStateChanged(String)
  AccountStateReasonChanged(String)
  AccountTierChanged(String)
  ResetClicked
  SaveClicked
  DeleteClicked
  DeleteCancelled
  DeleteDialogClosed
  DeleteConfirmed
  SaveFinished(api.ApiResponse(user_dto.UpdateUserResponse))
  DeleteFinished(api.ApiResponse(Nil))
}

pub fn init(id: uuid.Uuid) -> #(Model, Effect(Msg)) {
  #(
    Model(
      id: id,
      user: loadable.NotLoaded,
      pending_delete: option.None,
      delete_state: DeleteIdle,
    ),
    effect.none(),
  )
}

pub fn ensure_loaded(model: Model) -> #(Model, Effect(Msg)) {
  case
    loadable.ensure_loaded(
      model.user,
      api.get_admin_user(user_dto.GetUserRequest(id: model.id), UserLoaded),
    )
  {
    #(user, next_effect) -> #(Model(..model, user: user), next_effect)
  }
}

pub fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserLoaded(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            user: loadable.Loaded(editor_from_response(response.user)),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            user: loadable.LoadError(api.error_message(error)),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            user: loadable.LoadError("Could not load user."),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
      }

    UsernameChanged(value) -> #(
      update_editor(model, fn(editor) {
        UserEditor(
          ..editor,
          draft: UserFields(..editor.draft, username: value),
          state: mutation.Idle,
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
              state: mutation.Idle,
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
              state: mutation.Idle,
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
          state: mutation.Idle,
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
              state: mutation.Idle,
            )
          }),
          effect.none(),
        )
        option.None -> #(model, effect.none())
      }

    ResetClicked -> #(
      update_editor(model, fn(editor) {
        UserEditor(..editor, draft: editor.saved, state: mutation.Idle)
      }),
      effect.none(),
    )

    SaveClicked ->
      case model.user {
        loadable.Loaded(editor) ->
          case editor_to_request(editor) {
            Ok(request) -> #(
              update_editor(model, fn(current) {
                UserEditor(..current, state: mutation.Saving)
              }),
              api.update_admin_user(request, SaveFinished),
            )
            Error(message) -> #(
              update_editor(model, fn(current) {
                UserEditor(..current, state: mutation.SaveError(message))
              }),
              effect.none(),
            )
          }
        _ -> #(model, effect.none())
      }

    DeleteClicked ->
      case model.user {
        loadable.Loaded(editor) -> #(
          Model(..model, pending_delete: option.Some(editor)),
          app_dialog.open(delete_dialog_id),
        )
        _ -> #(model, effect.none())
      }

    DeleteCancelled -> #(model, app_dialog.close(delete_dialog_id))

    DeleteDialogClosed -> #(
      Model(..model, pending_delete: option.None),
      effect.none(),
    )

    DeleteConfirmed ->
      case model.pending_delete {
        option.Some(editor) -> #(
          Model(..model, delete_state: Deleting),
          effect.batch([
            app_dialog.close(delete_dialog_id),
            api.delete_admin_account(
              account_dto.DeleteAccountRequest(user_id: editor.id),
              DeleteFinished,
            ),
          ]),
        )
        option.None -> #(model, effect.none())
      }

    SaveFinished(result) ->
      case result {
        api.ApiSuccess(response) -> #(
          Model(
            ..model,
            user: loadable.Loaded(editor_from_response(response.user)),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
        api.ApiFailure(error) -> #(
          update_editor(model, fn(editor) {
            UserEditor(
              ..editor,
              state: mutation.SaveError(api.error_message(error)),
            )
          }),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          update_editor(model, fn(editor) {
            UserEditor(
              ..editor,
              state: mutation.SaveError("Could not update user."),
            )
          }),
          effect.none(),
        )
      }

    DeleteFinished(result) ->
      case result {
        api.ApiSuccess(_) -> #(
          Model(..model, pending_delete: option.None, delete_state: DeleteIdle),
          navigate_to_users(),
        )
        api.ApiFailure(error) -> #(
          Model(
            ..model,
            user: loadable.LoadError(api.error_message(error)),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
        api.HttpFailure(_) -> #(
          Model(
            ..model,
            user: loadable.LoadError("Could not delete account."),
            pending_delete: option.None,
            delete_state: DeleteIdle,
          ),
          effect.none(),
        )
      }
  }
}

pub fn view(model: Model, now: Timestamp) -> Element(Msg) {
  html.div([], [
    admin_ui.page_with_panel_class(
      panel_class: "admin-job-page",
      title: "User detail",
      intro: "Review account access and edit persisted user and account settings.",
      actions: [
        html.button(
          [
            attribute.type_("button"),
            attribute.class("admin-page__button admin-page__button--danger"),
            attribute.disabled(model.delete_state == Deleting),
            event.on_click(DeleteClicked),
          ],
          [
            html.text(case model.delete_state {
              Deleting -> "Deleting..."
              DeleteIdle -> "Delete account"
            }),
          ],
        ),
      ],
      content: [user_status(model), detail_view(model, now)],
    ),
    delete_confirmation_dialog(model),
  ])
}

fn user_status(model: Model) -> Element(Msg) {
  case model.user, model.delete_state {
    loadable.LoadError(message), _ -> admin_ui.error_status(message)
    loadable.Loading, _ -> admin_ui.status("Loading user...")
    _, Deleting -> admin_ui.status("Deleting account...")
    _, DeleteIdle -> admin_ui.status("")
  }
}

fn detail_view(model: Model, now: Timestamp) -> Element(Msg) {
  loadable.fold(
    model.user,
    admin_ui.empty_state("This user could not be loaded."),
    admin_ui.empty_state("Loading user..."),
    fn(editor) { user_view(editor, now, model.delete_state) },
    fn(_) { admin_ui.empty_state("This user could not be loaded.") },
  )
}

fn user_view(
  editor: UserEditor,
  now: Timestamp,
  delete_state: DeleteState,
) -> Element(Msg) {
  html.div([attribute.class("admin-job-page__content")], [
    html.div([attribute.class(admin_ui.summary_grid_class())], [
      admin_ui.summary_card("Role", role_text(editor.draft.role)),
      admin_ui.summary_card(
        "Access",
        account_state_text(editor.draft.account_state),
      ),
      admin_ui.summary_card(
        "Last login",
        timestamp_helpers.relative_label(editor.metadata.last_login_at, now),
      ),
    ]),
    admin_ui.section(
      title: "Metadata",
      copy: "Identifiers and read-only account attributes.",
      content: html.div([attribute.class(admin_ui.detail_grid_class())], [
        admin_ui.detail_item("User ID", uuid.to_string(editor.id)),
        admin_ui.detail_item("Account ID", uuid.to_string(editor.account_id)),
        admin_ui.detail_item(
          "Email",
          email_address_model.to_string(editor.email),
        ),
        admin_ui.detail_item(
          "Account deletion job ID",
          admin_format.optional_uuid(editor.metadata.delete_job_id),
        ),
        admin_ui.detail_item(
          "Account deletion scheduled at",
          admin_format.optional_timestamp(editor.metadata.delete_scheduled_at),
        ),
        admin_ui.detail_item(
          "Created at",
          admin_format.format_timestamp(editor.metadata.created_at),
        ),
        admin_ui.detail_item(
          "Updated at",
          admin_format.format_timestamp(editor.metadata.updated_at),
        ),
      ]),
    ),
    admin_ui.section(
      title: "Editable settings",
      copy: "Changes are persisted to the user and account records for this login identity.",
      content: edit_form(editor, delete_state == Deleting),
    ),
  ])
}

fn edit_form(editor: UserEditor, is_deleting: Bool) -> Element(Msg) {
  html.form(
    [
      attribute.class("admin-page__policy"),
      event.on_submit(fn(_) { SaveClicked }),
    ],
    [
      html.div([attribute.class("admin-page__modal-grid")], [
        admin_ui.text_input_with_attrs(
          label: "Username",
          help: "",
          value: editor.draft.username,
          placeholder: "",
          input_type: "text",
          field_class: "",
          input_class: "",
          input_attributes: [attribute.id("admin-user-username")],
          on_input: UsernameChanged,
        ),
        admin_ui.select_input_with_attrs(
          label: "Role",
          value: user_model.role_to_string(editor.draft.role),
          on_input: RoleChanged,
          options: role_options(),
          help: "",
          field_class: "",
          select_class: "",
          select_attributes: [attribute.id("admin-user-role")],
        ),
        admin_ui.select_input_with_attrs(
          label: "Account state",
          value: account_model.account_state_to_string(
            editor.draft.account_state,
          ),
          on_input: AccountStateChanged,
          options: account_state_options(),
          help: "",
          field_class: "",
          select_class: "",
          select_attributes: [attribute.id("admin-user-account-state")],
        ),
        admin_ui.select_input_with_attrs(
          label: "Account tier",
          value: account_model.account_tier_to_string(editor.draft.account_tier),
          on_input: AccountTierChanged,
          options: account_tier_options(),
          help: "",
          field_class: "",
          select_class: "",
          select_attributes: [attribute.id("admin-user-account-tier")],
        ),
        admin_ui.text_input_with_attrs(
          label: "Account state reason",
          help: "",
          value: editor.draft.account_state_reason,
          placeholder: "",
          input_type: "text",
          field_class: "",
          input_class: "",
          input_attributes: [attribute.id("admin-user-account-state-reason")],
          on_input: AccountStateReasonChanged,
        ),
      ]),
      admin_ui.form_status_block(save_status(editor.state)),
      admin_ui.form_actions([
        admin_ui.secondary_button(
          [
            attribute.type_("button"),
            attribute.disabled(
              mutation.is_saving(editor.state)
              || is_deleting
              || !is_dirty(editor),
            ),
            event.on_click(ResetClicked),
          ],
          "Reset",
        ),
        html.button(
          [
            attribute.type_("submit"),
            attribute.class("admin-page__button"),
            attribute.disabled(mutation.is_saving(editor.state) || is_deleting),
          ],
          [html.text(save_button_text(editor.state))],
        ),
      ]),
    ],
  )
}

fn delete_confirmation_dialog(model: Model) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(delete_dialog_id),
      attribute.class("app-dialog"),
      attribute.attribute("aria-label", "Delete account"),
      event.on("close", decode.success(DeleteDialogClosed)),
    ],
    delete_confirmation_dialog_children(model.pending_delete),
  )
}

fn delete_confirmation_dialog_children(
  pending_delete: option.Option(UserEditor),
) -> List(Element(Msg)) {
  case pending_delete {
    option.Some(editor) -> [
      admin_ui.dialog_form([], [
        admin_ui.dialog_intro("Delete account", [
          html.text("Delete "),
          html.code([], [html.text(editor.draft.username)]),
          html.text(" and immediately delete the account at "),
          html.code([], [
            html.text(email_address_model.to_string(editor.email)),
          ]),
          html.text(
            "? This also deletes snippets, sessions, and any scheduled account deletion job. This action cannot be undone.",
          ),
        ]),
        admin_ui.dialog_actions([
          admin_ui.dialog_cancel_button(
            [
              attribute.type_("button"),
              attribute.autofocus(True),
              event.on_click(DeleteCancelled),
            ],
            "Cancel",
          ),
          admin_ui.dialog_danger_button(
            [
              attribute.type_("button"),
              event.on_click(DeleteConfirmed),
            ],
            "Delete account",
          ),
        ]),
      ]),
    ]
    option.None -> []
  }
}

fn save_status(state: mutation.MutationState) -> Element(Msg) {
  admin_ui.mutation_status(state, "Saving user...", "User updated.")
}

fn save_button_text(state: mutation.MutationState) -> String {
  case state {
    mutation.Saving -> "Saving..."
    mutation.Idle | mutation.Saved | mutation.SaveError(_) -> "Save user"
  }
}

fn update_editor(model: Model, update: fn(UserEditor) -> UserEditor) -> Model {
  case model.user {
    loadable.Loaded(editor) ->
      Model(..model, user: loadable.Loaded(update(editor)))
    _ -> model
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
    state: mutation.Idle,
  )
}

fn editor_to_request(
  editor: UserEditor,
) -> Result(user_dto.UpdateUserRequest, String) {
  let username = string.trim(editor.draft.username)

  use _ <- result.try(
    user_model.validate_username(username)
    |> result.map_error(validation_error.message),
  )

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

fn navigate_to_users() -> Effect(Msg) {
  let #(path, query) = route.path_and_query(route.Admin(route.AdminUsers))
  modem.push(path, query, option.None)
}
