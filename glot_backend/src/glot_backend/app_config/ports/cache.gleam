import glot_backend/app_config/model/config.{type DynamicConfig}
import glot_backend/system/cache/cache_outcome.{type CacheOutcome}
import glot_backend/system/effect/error/db_error

pub type Cache {
  Cache(
    lookup: fn() ->
      #(Result(DynamicConfig, db_error.DbQueryError), CacheOutcome),
    refresh: fn() -> Result(DynamicConfig, db_error.DbQueryError),
  )
}
