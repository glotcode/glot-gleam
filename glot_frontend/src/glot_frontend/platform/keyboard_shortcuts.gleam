import lustre/effect.{type Effect}

pub fn bind(on_quick_actions: msg, on_editor_run: msg) -> Effect(msg) {
  effect.from(fn(dispatch) {
    bind_shortcuts(fn() { dispatch(on_quick_actions) }, fn() {
      dispatch(on_editor_run)
    })
  })
}

@external(javascript, "./keyboard_shortcuts_ffi.mjs", "bindShortcuts")
fn bind_shortcuts(
  on_quick_actions: fn() -> Nil,
  on_editor_run: fn() -> Nil,
) -> Nil
