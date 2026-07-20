import gleam/time/timestamp.{type Timestamp}
import glot_backend/app_config/model/entry.{type AppConfigEntry}
import glot_backend/system/effect/error/db_error

pub type Store {
  Store(
    list_entries: fn() -> Result(List(AppConfigEntry), db_error.DbQueryError),
    upsert_entries: fn(List(AppConfigEntry), Timestamp) ->
      Result(Nil, db_error.DbCommandError),
  )
}
