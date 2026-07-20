import glot_backend/system/cache/cache_outcome.{type CacheOutcome}
import glot_backend/system/effect/error/run_request_error
import glot_core/language.{type Language}
import glot_core/run.{type RunResult}

pub type LanguageVersionCache {
  LanguageVersionCache(
    lookup: fn(Language) ->
      #(Result(RunResult, run_request_error.RunRequestError), CacheOutcome),
  )
}
