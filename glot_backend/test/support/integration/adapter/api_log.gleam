import glot_backend/logging/api_log/ports/store
import support/integration/adapter/unexpected

pub fn defaults() -> store.Store {
  store.Store(
    list: fn(_) { unexpected.query("api_log.list") },
    get: fn(_) { unexpected.query("api_log.get") },
    delete_before: fn(_) { unexpected.command("api_log.delete_before") },
  )
}
