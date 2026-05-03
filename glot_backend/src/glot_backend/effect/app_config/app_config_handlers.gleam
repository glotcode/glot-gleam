import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/app_config
import glot_backend/effect/error
import glot_backend/helpers/db_helpers
import glot_backend/sql
import pog

pub type AppConfigHandlers {
  AppConfigHandlers(
    list_entries: fn() -> Result(List(app_config.AppConfigEntry), error.DbQueryError),
    upsert_entry: fn(String, String, String, Int, Timestamp) ->
      Result(Nil, error.DbCommandError),
  )
}

pub fn new(db: pog.Connection) -> AppConfigHandlers {
  AppConfigHandlers(
    list_entries: fn() { list_entries(db) },
    upsert_entry: fn(namespace, key, value, version, updated_at) {
      upsert_entry(db, namespace, key, value, version, updated_at)
    },
  )
}

pub fn list_entries(
  db: pog.Connection,
) -> Result(List(app_config.AppConfigEntry), error.DbQueryError) {
  db_helpers.query(db, sql.list_app_config(), fn(err) {
    error.DbQueryError(string.inspect(err))
  })
  |> result.map(fn(returned) { entries_from_rows(returned.rows) })
}

fn entries_from_rows(rows: List(sql.ListAppConfig)) -> List(app_config.AppConfigEntry) {
  list.map(rows, fn(row) {
    app_config.AppConfigEntry(
      namespace: row.namespace,
      key: row.key,
      value: row.value,
      version: row.version,
    )
  })
}

pub fn upsert_entry(
  db: pog.Connection,
  namespace: String,
  key: String,
  value: String,
  version: Int,
  updated_at: Timestamp,
) -> Result(Nil, error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.upsert_app_config(namespace:, key:, value:, version:, updated_at:),
    fn(err) { error.DbCommandError(string.inspect(err)) },
  )
  |> result.map(fn(_) { Nil })
}
