import lustre/effect.{type Effect}

pub const dialog_id = "editor-page-title-dialog"
pub const editor_id = "editor-page-codemirror"

pub fn open() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    open_dialog(dialog_id)
  })
}

pub fn close() -> Effect(msg) {
  effect.from(fn(_dispatch) {
    close_dialog(dialog_id)
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
