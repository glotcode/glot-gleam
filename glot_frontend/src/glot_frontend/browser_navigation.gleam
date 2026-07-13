import lustre/effect.{type Effect}

pub fn load(path: String) -> Effect(msg) {
  effect.from(fn(_dispatch) { assign(path) })
}

@external(javascript, "./browser_navigation_ffi.mjs", "assign")
fn assign(path: String) -> Nil
