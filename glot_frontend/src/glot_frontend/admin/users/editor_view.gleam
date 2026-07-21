import gleam/dynamic/decode
import gleam/option
import glot_core/auth/account_model
import glot_core/auth/user_model
import glot_core/email/email_address_model
import glot_frontend/admin/ui/dialog as admin_dialog
import glot_frontend/admin/ui/form as admin_form
import glot_frontend/admin/ui/layout as admin_layout
import glot_frontend/admin/ui/status as admin_status
import glot_frontend/admin/users/constants
import glot_frontend/admin/users/message.{
  type Msg, AccountStateChanged, AccountStateReasonChanged, AccountTierChanged,
  DeleteCancelled, DeleteConfirmed, DeleteDialogClosed, ResetClicked,
  RoleChanged, SaveClicked, UsernameChanged,
}
import glot_frontend/admin/users/model.{type Model, type UserEditor}
import glot_frontend/ui/mutation
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import lustre/event

pub fn form(editor: UserEditor, is_deleting: Bool) -> Element(Msg) {
  html.form(
    [
      attribute.class("admin-page__policy"),
      event.on_submit(fn(_) { SaveClicked }),
    ],
    [
      html.div([attribute.class("admin-page__modal-grid")], [
        admin_form.text_input_with_attrs(
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
        admin_form.select_input_with_attrs(
          label: "Role",
          value: user_model.role_to_string(editor.draft.role),
          on_input: RoleChanged,
          options: role_options(),
          help: "",
          field_class: "",
          select_class: "",
          select_attributes: [attribute.id("admin-user-role")],
        ),
        admin_form.select_input_with_attrs(
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
        admin_form.select_input_with_attrs(
          label: "Account tier",
          value: account_model.account_tier_to_string(editor.draft.account_tier),
          on_input: AccountTierChanged,
          options: account_tier_options(),
          help: "",
          field_class: "",
          select_class: "",
          select_attributes: [attribute.id("admin-user-account-tier")],
        ),
        admin_form.text_input_with_attrs(
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
      admin_layout.form_status_block(save_status(editor.state)),
      admin_layout.form_actions([
        admin_layout.secondary_button(
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

pub fn delete_dialog(model: Model) -> Element(Msg) {
  html.dialog(
    [
      attribute.id(constants.delete_dialog_id),
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
      admin_dialog.dialog_form([], [
        admin_dialog.dialog_intro("Delete account", [
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
        admin_dialog.dialog_actions([
          admin_dialog.dialog_cancel_button(
            [
              attribute.type_("button"),
              attribute.autofocus(True),
              event.on_click(DeleteCancelled),
            ],
            "Cancel",
          ),
          admin_dialog.dialog_danger_button(
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
  admin_status.mutation_status(state, "Saving user...", "User updated.")
}

fn save_button_text(state: mutation.MutationState) -> String {
  case state {
    mutation.Saving -> "Saving..."
    mutation.Idle | mutation.Saved | mutation.SaveError(_) -> "Save user"
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

pub fn role_text(role: user_model.UserRole) -> String {
  case role {
    user_model.RegularUser -> "User"
    user_model.AdminUser -> "Admin"
  }
}

pub fn account_state_text(account_state: account_model.AccountState) -> String {
  case account_state {
    account_model.Active -> "Active"
    account_model.ReadOnly -> "Read only"
    account_model.Suspended -> "Suspended"
  }
}
