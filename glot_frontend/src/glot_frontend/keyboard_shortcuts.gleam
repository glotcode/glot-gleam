import lustre/effect.{type Effect}

pub fn bind(on_quick_actions: msg) -> Effect(msg) {
  effect.from(fn(dispatch) {
    bind_shortcuts(fn() { dispatch(on_quick_actions) })
  })
}

@external(javascript, "./keyboard_shortcuts_ffi.mjs", "bindShortcuts")
fn bind_shortcuts(on_quick_actions: fn() -> Nil) -> Nil
