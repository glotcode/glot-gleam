import glot_backend/app_config/decoder/config as config_decoder
import glot_backend/app_config/ports/cache
import glot_backend/app_config/ports/store
import glot_backend/system/cache/cache_outcome
import glot_backend/system/effect/error/db_error
import support/integration/adapter/state
import support/integration/adapter/unexpected
import support/integration/model

pub fn default_store() -> store.Store {
  store.Store(
    list_entries: fn() { unexpected.query("app_config.list_entries") },
    upsert_entries: fn(_, _) { unexpected.command("app_config.upsert_entries") },
  )
}

pub fn store(test_state: state.State) -> store.Store {
  store.Store(list_entries: fn() { Ok([]) }, upsert_entries: fn(entries, _) {
    case config_decoder.from_entries(entries) {
      Ok(config) -> {
        state.update(test_state, fn(db) {
          model.TestState(..db, dynamic_config: config)
        })
        Ok(Nil)
      }
      Error(message) -> Error(db_error.DbCommandError(message))
    }
  })
}

pub fn cache(test_state: state.State) -> cache.Cache {
  cache.Cache(
    lookup: fn() {
      #(Ok(state.get(test_state).dynamic_config), cache_outcome.CacheHit)
    },
    refresh: fn() { Ok(state.get(test_state).dynamic_config) },
  )
}
