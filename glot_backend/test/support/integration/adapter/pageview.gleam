import glot_backend/logging/pageview/ports/store
import support/integration/adapter/unexpected

pub fn defaults() -> store.Store {
  store.Store(delete_before: fn(_) {
    unexpected.command("pageview.delete_before")
  })
}
