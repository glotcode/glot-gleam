import lustre/effect.{type Effect}

pub const title_dialog_id = "editor-page-title-dialog"
pub const add_entry_dialog_id = "editor-page-add-entry-dialog"
pub const edit_entry_dialog_id = "editor-page-edit-entry-dialog"
pub const settings_dialog_id = "editor-page-settings-dialog"
pub const save_dialog_id = "editor-page-save-dialog"
pub const snippet_info_dialog_id = "editor-page-snippet-info-dialog"
pub const editor_id = "editor-page-codemirror"

pub fn open_title_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    open_dialog(title_dialog_id)
  })
}

pub fn close_title_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    close_dialog(title_dialog_id)
  })
}

pub fn open_add_entry_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    open_dialog(add_entry_dialog_id)
  })
}

pub fn close_add_entry_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    close_dialog(add_entry_dialog_id)
  })
}

pub fn open_edit_entry_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    open_dialog(edit_entry_dialog_id)
  })
}

pub fn close_edit_entry_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    close_dialog(edit_entry_dialog_id)
  })
}

pub fn open_settings_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    open_dialog(settings_dialog_id)
  })
}

pub fn close_settings_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    close_dialog(settings_dialog_id)
  })
}

pub fn open_save_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    open_dialog(save_dialog_id)
  })
}

pub fn close_save_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    close_dialog(save_dialog_id)
  })
}

pub fn open_snippet_info_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    open_dialog(snippet_info_dialog_id)
  })
}

pub fn close_snippet_info_dialog() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    close_dialog(snippet_info_dialog_id)
  })
}

pub fn focus_editor() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    focus_element(editor_id)
  })
}

@external(javascript, "./editor_dialog_ffi.mjs", "openDialog")
fn open_dialog(id: String) -> Nil

@external(javascript, "./editor_dialog_ffi.mjs", "closeDialog")
fn close_dialog(id: String) -> Nil

@external(javascript, "./editor_dialog_ffi.mjs", "focusElement")
fn focus_element(id: String) -> Nil
