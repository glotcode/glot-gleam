import gleam/list
import gleam/result
import gleam/string
import gleam/time/timestamp
import glot_backend/app_config/model/entry.{type AppConfigEntry}
import glot_backend/app_config/ports/store.{type Store}
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error

pub fn new(db: db_helpers.Db) -> Store {
  store.Store(
    list_entries: fn() { list_entries(db) },
    upsert_entries: fn(entries, updated_at) {
      upsert_entries(db, entries, updated_at)
    },
  )
}

fn list_entries(
  db: db_helpers.Db,
) -> Result(List(AppConfigEntry), db_error.DbQueryError) {
  db_helpers.query(db, sql.list_app_config(), fn(err) {
    db_error.DbQueryError(string.inspect(err))
  })
  |> result.map(fn(returned) { entries_from_rows(returned.rows) })
}

fn entries_from_rows(rows: List(sql.ListAppConfig)) -> List(AppConfigEntry) {
  list.map(rows, fn(row) {
    entry.AppConfigEntry(
      namespace: row.namespace,
      key: row.key,
      value: row.value,
    )
  })
}

fn upsert_entry(
  db: db_helpers.Db,
  namespace: String,
  key: String,
  value: String,
  updated_at: timestamp.Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  db_helpers.execute(
    db,
    sql.upsert_app_config(namespace:, key:, value:, updated_at:),
    fn(err) { db_error.DbCommandError(string.inspect(err)) },
  )
  |> result.map(fn(_) { Nil })
}

fn upsert_entries(
  db: db_helpers.Db,
  entries: List(AppConfigEntry),
  updated_at: timestamp.Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  list.fold(entries, Ok(Nil), fn(acc, entry) {
    use _ <- result.try(acc)
    upsert_entry(db, entry.namespace, entry.key, entry.value, updated_at)
  })
}
