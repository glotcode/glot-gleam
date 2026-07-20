import gleam/erlang/process
import glot_backend/app_config/ports/cache.{type Cache}
import glot_backend/app_config/worker/cache/worker as cache_worker
import glot_backend/system/cache/worker/support as cache_worker_support

pub fn new(subject: process.Subject(cache_worker.Message)) -> Cache {
  cache.Cache(
    lookup: fn() {
      let cache_worker_support.Lookup(value:, outcome:) =
        cache_worker.lookup_config(subject)
      #(value, outcome)
    },
    refresh: fn() { cache_worker.refresh(subject) },
  )
}
