import glot_backend/logging/page_log/ports/store
import support/integration/adapter/unexpected

pub fn defaults() -> store.Store {
  store.Store(delete_before: fn(_) {
    unexpected.command("page_log.delete_before")
  })
}
