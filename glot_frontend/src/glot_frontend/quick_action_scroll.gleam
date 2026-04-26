import lustre/effect.{type Effect}

pub fn ensure_visible(index: Int) -> Effect(msg) {
  effect.from(fn(_dispatch) { scroll_to_selected(index) })
}

@external(javascript, "./quick_action_scroll_ffi.mjs", "scrollToSelected")
fn scroll_to_selected(index: Int) -> Nil
