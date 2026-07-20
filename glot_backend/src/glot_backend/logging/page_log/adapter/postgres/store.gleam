import gleam/result
import gleam/string
import gleam/time/timestamp.{type Timestamp}
import glot_backend/logging/page_log/ports/store as page_log_store
import glot_backend/sql
import glot_backend/system/database as db_helpers
import glot_backend/system/effect/error/db_error

pub fn new(db: db_helpers.Db) -> page_log_store.Store {
  page_log_store.Store(delete_before: fn(before) { delete_before(db, before) })
}

pub fn delete_before(
  db: db_helpers.Db,
  before: Timestamp,
) -> Result(Nil, db_error.DbCommandError) {
  let to_error = fn(err) { db_error.DbCommandError(string.inspect(err)) }

  db_helpers.execute(db, sql.delete_page_log_before(before), to_error)
  |> result.map(fn(_) { Nil })
}
