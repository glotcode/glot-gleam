import gleam/erlang/process
import glot_backend/run_code/ports/language_version_cache.{
  type LanguageVersionCache,
}
import glot_backend/run_code/worker/language_version_cache/worker as cache_worker
import glot_backend/system/cache/worker/support as cache_worker_support

pub fn new(
  subject: process.Subject(cache_worker.Message),
) -> LanguageVersionCache {
  language_version_cache.LanguageVersionCache(lookup: fn(language) {
    let cache_worker_support.Lookup(value:, outcome:) =
      cache_worker.lookup_language_version(subject, language)
    #(value, outcome)
  })
}
