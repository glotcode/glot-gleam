import lustre/effect.{type Effect}

pub fn open(id: String) -> Effect(msg) {
  effect.from(fn(_dispatch) { open_dialog(id) })
}

pub fn close(id: String) -> Effect(msg) {
  effect.from(fn(_dispatch) { close_dialog(id) })
}

@external(javascript, "./app_dialog_ffi.mjs", "openDialog")
fn open_dialog(id: String) -> Nil

@external(javascript, "./app_dialog_ffi.mjs", "closeDialog")
fn close_dialog(id: String) -> Nil
